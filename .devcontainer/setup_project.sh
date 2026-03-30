#!/bin/bash
set -uo pipefail
# Note: no -e — we handle errors explicitly so partial failures don't abort

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

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
  --org <org>         GitHub org for the DCA instance repo (default: aiwonglab)
  --template <repo>   Template repo to clone (default: aiwonglab/DevCon_claude)
  --agents <repo>     Agents repo (default: wshobson/agents)
  --commands <repo>   Commands repo (default: wshobson/commands)
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
  bash setup_project.sh praxis --org other-org --no-mount --ssh
  bash setup_project.sh praxis --dry-run
  bash setup_project.sh praxis --github-only
EOF
    exit 0
}

# ─── Parse args ───────────────────────────────────────────────────────────────
PROJECT=""
ORG="aiwonglab"
TEMPLATE_REPO="aiwonglab/DevCon_claude"
AGENTS_REPO="wshobson/agents"
COMMANDS_REPO="wshobson/commands"
DRY_RUN=false
MOUNT_MODE=""       # "", "path", "none"
MOUNT_PATH=""
GIT_PROTOCOL=""     # "", "ssh", "https"
GITHUB_ONLY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage ;;
        --org) ORG="$2"; shift 2 ;;
        --template) TEMPLATE_REPO="$2"; shift 2 ;;
        --agents) AGENTS_REPO="$2"; shift 2 ;;
        --commands) COMMANDS_REPO="$2"; shift 2 ;;
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
INSTANCE_REPO="${ORG}/${REPO_NAME}"

# ─── Helpers ──────────────────────────────────────────────────────────────────
run() {
    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY-RUN]${NC} $*"
    else
        eval "$@"
    fi
}

# Portable sed -i (macOS requires '' argument)
detect_os() {
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        Darwin*)               echo "mac" ;;
        *)                     echo "linux" ;;
    esac
}

HOST_OS=$(detect_os)

sedi() {
    if [[ "$HOST_OS" == "mac" ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

# Clone a repo into .claude/_upstream/, non-fatal on failure
clone_upstream() {
    local label="$1" repo="$2" dest="$3"
    info "Cloning ${label} from ${repo}..."
    if $DRY_RUN; then
        run "git clone $(git_url "${repo}") ${dest}"
        return 0
    elif git clone "$(git_url "${repo}")" "${dest}" 2>/dev/null; then
        ok "${label} cloned"
        return 0
    else
        warn "Failed to clone ${label} repo (${repo}). Skipping."
        warn "You can clone it manually later into ${dest}"
        return 1
    fi
}

# ─── Detect git protocol ─────────────────────────────────────────────────────
if [[ -z "$GIT_PROTOCOL" ]]; then
    if command -v gh &>/dev/null && gh auth status &>/dev/null; then
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
    if [[ ! -d "$REPO_NAME" ]]; then
        err "Directory '$REPO_NAME' does not exist. Run without --github-only first."
        exit 1
    fi

    if ! command -v gh &>/dev/null || ! gh auth status &>/dev/null; then
        err "GitHub CLI (gh) is required for --github-only. Run 'gh auth login' first."
        exit 1
    fi

    cd "$REPO_NAME"
    info "Creating GitHub repo ${INSTANCE_REPO}..."

    if gh repo view "$INSTANCE_REPO" &>/dev/null; then
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
if [[ -d "$REPO_NAME" ]]; then
    err "Directory '$REPO_NAME' already exists. Aborting."
    exit 1
fi

if ! command -v git &>/dev/null; then
    err "'git' is required but not found."
    exit 1
fi

HAS_GH=false
if command -v gh &>/dev/null && gh auth status &>/dev/null; then
    HAS_GH=true
    ok "GitHub CLI authenticated"
else
    warn "GitHub CLI (gh) not available or not authenticated."
    warn "Repo creation will be skipped — create it manually on GitHub."
fi

info "Detected host OS: $HOST_OS"

# ─── Resolve bind mount ──────────────────────────────────────────────────────
if [[ "$MOUNT_MODE" == "path" ]]; then
    info "Bind mount: ${MOUNT_PATH} → /workspace/src/${PROJECT}/"
elif [[ "$MOUNT_MODE" == "none" ]]; then
    info "Skipping bind mount"
else
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
        read -rp "Host path to project source [${DEFAULT_PATH}]: " MOUNT_PATH
        MOUNT_PATH="${MOUNT_PATH:-$DEFAULT_PATH}"
        MOUNT_MODE="path"
        info "Bind mount: ${MOUNT_PATH} → /workspace/src/${PROJECT}/"
    fi
fi

# ─── Step 1: Clone template ──────────────────────────────────────────────────
echo ""
info "Cloning template repo ${TEMPLATE_REPO} into ${REPO_NAME}..."
run "git clone $(git_url "$TEMPLATE_REPO") '${REPO_NAME}'"

if ! $DRY_RUN; then
    cd "$REPO_NAME"
else
    info "Would cd into ${REPO_NAME}"
fi

# ─── Step 2: Set up agents and commands (non-fatal) ───────────────────────────
echo ""
info "Setting up Claude Code agents and commands..."

run "mkdir -p .claude/_upstream"

AGENTS_OK=false
clone_upstream "agents" "$AGENTS_REPO" ".claude/_upstream/agents-repo" && AGENTS_OK=true

COMMANDS_OK=false
clone_upstream "commands" "$COMMANDS_REPO" ".claude/_upstream/commands-repo" && COMMANDS_OK=true

if ! $DRY_RUN; then
    $AGENTS_OK && ln -sfn _upstream/agents-repo .claude/agents
    $COMMANDS_OK && ln -sfn _upstream/commands-repo .claude/commands
    ($AGENTS_OK || $COMMANDS_OK) && ok "Symlinks created"
else
    info "Would create symlinks: .claude/agents → _upstream/agents-repo, .claude/commands → _upstream/commands-repo"
fi

# ─── Step 3: Create src and data dirs ────────────────────────────────────────
run "mkdir -p src data"

# ─── Step 4: Update devcontainer.json ─────────────────────────────────────────
echo ""
info "Updating devcontainer.json..."

if ! $DRY_RUN; then
    DC=".devcontainer/devcontainer.json"

    sedi \
        -e "s/\"name\": \".*\"/\"name\": \"DCA: ${PROJECT}\"/" \
        -e "s/\"source=claude-code-bashhistory,/\"source=claude-code-bashhistory-${PROJECT},/" \
        -e "s/\"source=claude-code-config,/\"source=claude-code-config-${PROJECT},/" \
        "$DC"

    if [[ -n "$MOUNT_PATH" && "$MOUNT_MODE" == "path" ]]; then
        MOUNT_LINE="    \"source=${MOUNT_PATH},target=/workspace/src/${PROJECT},type=bind,consistency=delegated\""
        sedi "/\"source=claude-code-config/a\\
${MOUNT_LINE}" "$DC"
        sedi "s|\"source=claude-code-config-${PROJECT},target=/home/node/.claude,type=volume\"|\"source=claude-code-config-${PROJECT},target=/home/node/.claude,type=volume\",|" "$DC"
    fi

    ok "devcontainer.json updated"
else
    info "Would update container name to 'DCA: ${PROJECT}'"
    info "Would update volume mount suffixes with '${PROJECT}'"
    if [[ "$MOUNT_MODE" == "path" ]]; then
        info "Would add bind mount: ${MOUNT_PATH} → /workspace/src/${PROJECT}/"
    fi
fi

# ─── Step 5: Write project README ────────────────────────────────────────────
echo ""
info "Writing project README..."

if ! $DRY_RUN; then
    cat > README.md <<READMEEOF
# DCA_${PROJECT}

Development container instance for **${PROJECT}**, created from the [DevCon_claude](https://github.com/${TEMPLATE_REPO}) template.

## Remotes

| Remote   | Repository                                                                  |
|----------|-----------------------------------------------------------------------------|
| origin   | [${ORG}/${REPO_NAME}](https://github.com/${INSTANCE_REPO})                 |
| upstream | [${TEMPLATE_REPO}](https://github.com/${TEMPLATE_REPO})                    |

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
        if gh repo view "$INSTANCE_REPO" &>/dev/null; then
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
$([ "$MOUNT_MODE" == "path" ] && echo "- Add bind mount: ${MOUNT_PATH} → /workspace/src/${PROJECT}/")"

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
echo "    1. Open ${REPO_NAME}/ in VS Code"
echo "    2. Reopen in container"
echo "    3. Start working in /workspace/src/${PROJECT}/"
echo ""
if ! $HAS_GH; then
    echo "  GitHub repo not created yet. When gh is available, run:"
    echo "    bash setup_project.sh ${PROJECT} --github-only"
    echo ""
fi
