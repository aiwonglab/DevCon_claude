#!/bin/bash
set -uo pipefail
# Note: no -e — we handle errors explicitly so partial failures don't abort

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; }

# ─── Usage ────────────────────────────────────────────────────────────────────
usage() {
    cat <<'EOF'
Usage: bash setup_project.sh <project-name> [options]

Creates a new DCA instance from the DevCon_claude template.

Arguments:
  project-name        Name of the project (e.g. praxis, livelingual)
                      Must be alphanumeric, hyphens, or underscores only.

Options:
  --org <org>         GitHub org (default: aiwonglab)
  --mount <path>      Add a bind mount from host path to /workspace/src/<project>
  --no-mount          Skip bind mount (no interactive prompt)
  --ssh               Use SSH URLs for git remotes (default: auto-detect from gh)
  --https             Use HTTPS URLs for git remotes
  --github-only       Only create the GitHub repo, set remotes, and push
                      (for instances that were set up without gh earlier)
  --dry-run           Show what would happen without making changes
  -h, --help          Show this help message

Examples:
  bash setup_project.sh praxis
  bash setup_project.sh praxis --mount C:/git/praxis
  bash setup_project.sh praxis --no-mount --ssh
  bash setup_project.sh praxis --org myorg --dry-run
  bash setup_project.sh praxis --github-only          # add GitHub repo later
EOF
    exit 0
}

# ─── Parse args ───────────────────────────────────────────────────────────────
PROJECT=""
ORG="aiwonglab"
DRY_RUN=false
MOUNT_MODE=""       # "", "path", "none"
MOUNT_PATH=""
GIT_PROTOCOL=""     # "", "ssh", "https"
GITHUB_ONLY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage ;;
        --org) ORG="$2"; shift 2 ;;
        --mount) MOUNT_MODE="path"; MOUNT_PATH="$2"; shift 2 ;;
        --no-mount) MOUNT_MODE="none"; shift ;;
        --ssh) GIT_PROTOCOL="ssh"; shift ;;
        --https) GIT_PROTOCOL="https"; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --github-only) GITHUB_ONLY=true; shift ;;
        -*) err "Unknown option: $1"; usage ;;
        *)
            if [[ -z "$PROJECT" ]]; then
                PROJECT="$1"; shift
            else
                err "Unexpected argument: $1"; usage
            fi
            ;;
    esac
done

if [[ -z "$PROJECT" ]]; then
    err "Project name is required"
    usage
fi

# ─── Validate project name ───────────────────────────────────────────────────
if [[ ! "$PROJECT" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    err "Project name must be alphanumeric, hyphens, or underscores only."
    err "Got: '$PROJECT'"
    exit 1
fi

REPO_NAME="DCA_${PROJECT}"
TEMPLATE_REPO="${ORG}/DevCon_claude"
INSTANCE_REPO="${ORG}/${REPO_NAME}"
TARGET_DIR="${REPO_NAME}"

# ─── Dry-run wrapper ─────────────────────────────────────────────────────────
run() {
    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY-RUN]${NC} $*"
    else
        eval "$@"
    fi
}

# ─── Detect git protocol ─────────────────────────────────────────────────────
if [[ -z "$GIT_PROTOCOL" ]]; then
    if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
        GIT_PROTOCOL=$(gh config get git_protocol 2>/dev/null || echo "https")
    else
        GIT_PROTOCOL="https"
    fi
fi

git_url() {
    local repo="$1"
    if [[ "$GIT_PROTOCOL" == "ssh" ]]; then
        echo "git@github.com:${repo}.git"
    else
        echo "https://github.com/${repo}.git"
    fi
}

info "Git protocol: $GIT_PROTOCOL"

# ─── GitHub-only mode ─────────────────────────────────────────────────────────
if $GITHUB_ONLY; then
    if [[ ! -d "$TARGET_DIR" ]]; then
        err "Directory '$TARGET_DIR' does not exist. Run without --github-only first."
        exit 1
    fi

    if ! command -v gh &>/dev/null || ! gh auth status &>/dev/null 2>&1; then
        err "GitHub CLI (gh) is required for --github-only. Run 'gh auth login' first."
        exit 1
    fi

    cd "$TARGET_DIR"
    info "Creating GitHub repo ${INSTANCE_REPO}..."

    if gh repo view "$INSTANCE_REPO" &>/dev/null 2>&1; then
        warn "GitHub repo ${INSTANCE_REPO} already exists"
    else
        if ! gh repo create "$INSTANCE_REPO" --private --description "DCA instance for ${PROJECT}"; then
            err "Failed to create GitHub repo"
            exit 1
        fi
        ok "GitHub repo created"
    fi

    git remote set-url origin "$(git_url "$INSTANCE_REPO")" 2>/dev/null || \
        git remote add origin "$(git_url "$INSTANCE_REPO")"
    ok "Origin remote set to $(git_url "$INSTANCE_REPO")"

    info "Pushing to origin..."
    if git push -u origin master; then
        ok "Pushed to ${INSTANCE_REPO}"
    else
        err "Push failed"
        exit 1
    fi

    echo ""
    ok "GitHub repo is set up: https://github.com/${INSTANCE_REPO}"
    exit 0
fi

# ─── Preflight checks ────────────────────────────────────────────────────────
if [[ -d "$TARGET_DIR" ]]; then
    err "Directory '$TARGET_DIR' already exists. Aborting."
    exit 1
fi

if ! command -v git &>/dev/null; then
    err "'git' is required but not found."
    exit 1
fi

# Check gh availability (optional — used for repo creation)
HAS_GH=false
if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
    HAS_GH=true
    ok "GitHub CLI authenticated"
else
    warn "GitHub CLI (gh) not available or not authenticated."
    warn "Repo creation will be skipped — create it manually on GitHub."
fi

# ─── Detect host OS ──────────────────────────────────────────────────────────
detect_os() {
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        Darwin*)               echo "mac" ;;
        *)                     echo "linux" ;;
    esac
}

HOST_OS=$(detect_os)
info "Detected host OS: $HOST_OS"

# ─── Resolve bind mount ──────────────────────────────────────────────────────
HOST_PATH=""
if [[ "$MOUNT_MODE" == "path" ]]; then
    HOST_PATH="$MOUNT_PATH"
    info "Bind mount: ${HOST_PATH} → /workspace/src/${PROJECT}/"
elif [[ "$MOUNT_MODE" == "none" ]]; then
    info "Skipping bind mount"
else
    # Interactive prompt
    echo ""
    echo -e "${CYAN}Bind mount setup${NC}"
    echo "A bind mount maps a host directory into /workspace/src/${PROJECT}/"
    echo "so your project source code is available inside the container."
    echo ""
    read -rp "Add a bind mount for project source? [Y/n] " ADD_MOUNT
    ADD_MOUNT="${ADD_MOUNT:-Y}"

    if [[ "$ADD_MOUNT" =~ ^[Yy]$ ]]; then
        if [[ "$HOST_OS" == "windows" ]]; then
            DEFAULT_PATH="C:/git/${PROJECT}"
        else
            DEFAULT_PATH="${HOME}/git/${PROJECT}"
        fi
        read -rp "Host path to project source [${DEFAULT_PATH}]: " HOST_PATH
        HOST_PATH="${HOST_PATH:-$DEFAULT_PATH}"
        info "Bind mount: ${HOST_PATH} → /workspace/src/${PROJECT}/"
    fi
fi

# ─── Step 1: Clone template ──────────────────────────────────────────────────
echo ""
info "Cloning template repo ${TEMPLATE_REPO} into ${TARGET_DIR}..."
run "git clone $(git_url "$TEMPLATE_REPO") '${TARGET_DIR}'"

if ! $DRY_RUN; then
    cd "$TARGET_DIR"
else
    info "Would cd into ${TARGET_DIR}"
fi

# ─── Step 2: Set up agents and commands (non-fatal) ───────────────────────────
echo ""
info "Setting up Claude Code agents and commands in .claude/_upstream/..."

run "mkdir -p .claude/_upstream"

AGENTS_OK=false
info "Cloning agents..."
if $DRY_RUN; then
    run "git clone $(git_url "${ORG}/claude_code_agents") .claude/_upstream/agents-repo"
    info "Would add upstream remote for agents"
    AGENTS_OK=true
elif git clone "$(git_url "${ORG}/claude_code_agents")" .claude/_upstream/agents-repo 2>/dev/null; then
    cd .claude/_upstream/agents-repo
    git remote add upstream "$(git_url "wshobson/agents")" 2>/dev/null || true
    cd ../../..
    AGENTS_OK=true
    ok "Agents cloned"
else
    warn "Failed to clone agents repo (${ORG}/claude_code_agents). Skipping."
    warn "You can clone it manually later into .claude/_upstream/agents-repo"
fi

COMMANDS_OK=false
info "Cloning commands..."
if $DRY_RUN; then
    run "git clone $(git_url "${ORG}/claude_code_commands") .claude/_upstream/commands-repo"
    info "Would add upstream remote for commands"
    COMMANDS_OK=true
elif git clone "$(git_url "${ORG}/claude_code_commands")" .claude/_upstream/commands-repo 2>/dev/null; then
    cd .claude/_upstream/commands-repo
    git remote add upstream "$(git_url "wshobson/commands")" 2>/dev/null || true
    cd ../../..
    COMMANDS_OK=true
    ok "Commands cloned"
else
    warn "Failed to clone commands repo (${ORG}/claude_code_commands). Skipping."
    warn "You can clone it manually later into .claude/_upstream/commands-repo"
fi

# Set up symlinks (only for repos that were cloned)
if ! $DRY_RUN; then
    if $AGENTS_OK; then
        ln -sfn _upstream/agents-repo .claude/agents
    fi
    if $COMMANDS_OK; then
        ln -sfn _upstream/commands-repo .claude/commands
    fi
    if $AGENTS_OK || $COMMANDS_OK; then
        ok "Symlinks created"
    fi
else
    info "Would create symlinks: .claude/agents → _upstream/agents-repo, .claude/commands → _upstream/commands-repo"
fi

# ─── Step 3: Create src and data dirs ────────────────────────────────────────
run "mkdir -p src data"

# ─── Step 4: Update devcontainer.json ─────────────────────────────────────────
echo ""
info "Updating devcontainer.json..."

if ! $DRY_RUN; then
    DEVCONTAINER=".devcontainer/devcontainer.json"

    # Update container name and volume suffixes
    if [[ "$HOST_OS" == "mac" ]]; then
        sed -i '' "s/\"name\": \".*\"/\"name\": \"DCA: ${PROJECT}\"/" "$DEVCONTAINER"
        sed -i '' "s/\"source=claude-code-bashhistory,/\"source=claude-code-bashhistory-${PROJECT},/" "$DEVCONTAINER"
        sed -i '' "s/\"source=claude-code-config,/\"source=claude-code-config-${PROJECT},/" "$DEVCONTAINER"
    else
        sed -i "s/\"name\": \".*\"/\"name\": \"DCA: ${PROJECT}\"/" "$DEVCONTAINER"
        sed -i "s/\"source=claude-code-bashhistory,/\"source=claude-code-bashhistory-${PROJECT},/" "$DEVCONTAINER"
        sed -i "s/\"source=claude-code-config,/\"source=claude-code-config-${PROJECT},/" "$DEVCONTAINER"
    fi

    # Add bind mount if requested
    if [[ -n "$HOST_PATH" ]]; then
        MOUNT_LINE="    \"source=${HOST_PATH},target=/workspace/src/${PROJECT},type=bind,consistency=delegated\""

        if [[ "$HOST_OS" == "mac" ]]; then
            sed -i '' "/\"source=claude-code-config/a\\
${MOUNT_LINE}" "$DEVCONTAINER"
            sed -i '' "s|\"source=claude-code-config-${PROJECT},target=/home/node/.claude,type=volume\"|\"source=claude-code-config-${PROJECT},target=/home/node/.claude,type=volume\",|" "$DEVCONTAINER"
        else
            sed -i "/\"source=claude-code-config/a\\
${MOUNT_LINE}" "$DEVCONTAINER"
            sed -i "s|\"source=claude-code-config-${PROJECT},target=/home/node/.claude,type=volume\"|\"source=claude-code-config-${PROJECT},target=/home/node/.claude,type=volume\",|" "$DEVCONTAINER"
        fi
    fi

    ok "devcontainer.json updated"
else
    info "Would update container name to 'DCA: ${PROJECT}'"
    info "Would update volume mount suffixes with '${PROJECT}'"
    if [[ -n "$HOST_PATH" ]]; then
        info "Would add bind mount: ${HOST_PATH} → /workspace/src/${PROJECT}/"
    fi
fi

# ─── Step 5: Write project README ────────────────────────────────────────────
echo ""
info "Writing project README..."

if ! $DRY_RUN; then
    cat > README.md <<READMEEOF
# DCA_${PROJECT}

Development container instance for **${PROJECT}**, created from the [DevCon_claude](https://github.com/${ORG}/DevCon_claude) template.

## Remotes

| Remote   | Repository                                                                  |
|----------|-----------------------------------------------------------------------------|
| origin   | [${ORG}/${REPO_NAME}](https://github.com/${INSTANCE_REPO})                 |
| upstream | [${ORG}/DevCon_claude](https://github.com/${TEMPLATE_REPO})                |

## Quick Start

1. Open this repo in VS Code
2. Reopen in container (Dev Containers extension)
3. Project source is available at \`/workspace/src/${PROJECT}/\`

## Pulling Template Updates

\`\`\`bash
git fetch upstream master
git merge upstream/master
\`\`\`

## Project Structure

\`\`\`
/workspace/
├── .devcontainer/     # Container configuration
├── .claude/
│   ├── agents/        # Claude Code agents
│   └── commands/      # Claude Code commands
├── src/${PROJECT}/    # Project source (bind mount from host)
├── data/              # Data files
├── output/            # Generated outputs
└── results/           # Results
\`\`\`
READMEEOF
    ok "README.md written"
else
    info "Would write project-specific README.md"
fi

# ─── Step 6: Create GitHub repo (optional — requires gh) ─────────────────────
echo ""
if $HAS_GH; then
    info "Setting up GitHub repo ${INSTANCE_REPO}..."

    if ! $DRY_RUN; then
        if gh repo view "$INSTANCE_REPO" &>/dev/null 2>&1; then
            warn "GitHub repo ${INSTANCE_REPO} already exists, skipping creation"
        else
            info "Creating GitHub repo ${INSTANCE_REPO}..."
            if gh repo create "$INSTANCE_REPO" --private --description "DCA instance for ${PROJECT}"; then
                ok "GitHub repo created"
            else
                warn "Failed to create GitHub repo. Create it manually:"
                warn "  gh repo create ${INSTANCE_REPO} --private"
            fi
        fi
    else
        info "Would create GitHub repo: ${INSTANCE_REPO} (private)"
    fi
else
    warn "Skipping GitHub repo creation (gh not available)"
    warn "Create it manually, then push:"
    warn "  gh repo create ${INSTANCE_REPO} --private"
    warn "  git push -u origin master"
fi

# ─── Step 7: Configure git remotes ───────────────────────────────────────────
echo ""
info "Configuring git remotes..."

if ! $DRY_RUN; then
    git remote set-url origin "$(git_url "$INSTANCE_REPO")"
    git remote add upstream "$(git_url "$TEMPLATE_REPO")" 2>/dev/null || \
        git remote set-url upstream "$(git_url "$TEMPLATE_REPO")"

    ok "Remotes configured:"
    git remote -v
else
    info "Would set origin  → $(git_url "$INSTANCE_REPO")"
    info "Would set upstream → $(git_url "$TEMPLATE_REPO")"
fi

# ─── Step 8: Commit and push ─────────────────────────────────────────────────
echo ""
info "Committing instance configuration..."

if ! $DRY_RUN; then
    git add -A
    git commit -m "Configure DCA instance for ${PROJECT}

- Set container name to DCA: ${PROJECT}
- Configure project-specific volume mounts
- Write project README
$([ -n "$HOST_PATH" ] && echo "- Add bind mount: ${HOST_PATH} → /workspace/src/${PROJECT}/")"

    if $HAS_GH; then
        info "Pushing to origin..."
        if git push -u origin master; then
            ok "Pushed to ${INSTANCE_REPO}"
        else
            warn "Push failed. Push manually: git push -u origin master"
        fi
    else
        info "Skipping push (no GitHub repo created). Push manually after creating the repo."
    fi
else
    info "Would commit and push instance configuration"
fi

# ─── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Instance ${REPO_NAME} is ready!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Repository: https://github.com/${INSTANCE_REPO}"
echo "  Local dir:  $(pwd)"
echo ""
echo "  Next steps:"
echo "    1. Open ${TARGET_DIR}/ in VS Code"
echo "    2. Reopen in container"
echo "    3. Start working in /workspace/src/${PROJECT}/"
echo ""
if ! $HAS_GH; then
    echo "  GitHub repo not created yet. When gh is available, run:"
    echo "    bash setup_project.sh ${PROJECT} --github-only"
    echo ""
fi
