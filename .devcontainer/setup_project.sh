#!/bin/bash
set -euo pipefail

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

Options:
  --org <org>         GitHub org (default: aiwonglab)
  --dry-run           Show what would happen without making changes
  -h, --help          Show this help message

Examples:
  bash setup_project.sh praxis
  bash setup_project.sh praxis --org myorg
  bash setup_project.sh praxis --dry-run
EOF
    exit 0
}

# ─── Parse args ───────────────────────────────────────────────────────────────
PROJECT=""
ORG="aiwonglab"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage ;;
        --org) ORG="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
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

# ─── Preflight checks ────────────────────────────────────────────────────────
if [[ -d "$TARGET_DIR" ]]; then
    err "Directory '$TARGET_DIR' already exists. Aborting."
    exit 1
fi

if ! command -v gh &>/dev/null; then
    err "'gh' (GitHub CLI) is required but not found. Install it first."
    exit 1
fi

if ! command -v git &>/dev/null; then
    err "'git' is required but not found."
    exit 1
fi

# Check gh auth
if ! gh auth status &>/dev/null 2>&1; then
    err "Not authenticated with GitHub CLI. Run 'gh auth login' first."
    exit 1
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

# ─── Prompt for bind mount ───────────────────────────────────────────────────
echo ""
echo -e "${CYAN}Bind mount setup${NC}"
echo "A bind mount maps a host directory into /workspace/src/${PROJECT}/"
echo "so your project source code is available inside the container."
echo ""
read -rp "Add a bind mount for project source? [Y/n] " ADD_MOUNT
ADD_MOUNT="${ADD_MOUNT:-Y}"

HOST_PATH=""
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

# ─── Step 1: Clone template ──────────────────────────────────────────────────
echo ""
info "Cloning template repo ${TEMPLATE_REPO} into ${TARGET_DIR}..."
run "git clone https://github.com/${TEMPLATE_REPO}.git '${TARGET_DIR}'"

if ! $DRY_RUN; then
    cd "$TARGET_DIR"
else
    info "Would cd into ${TARGET_DIR}"
fi

# ─── Step 2: Set up agents and commands ───────────────────────────────────────
echo ""
info "Setting up Claude Code agents and commands in .claude/_upstream/..."

run "mkdir -p .claude/_upstream"

info "Cloning agents..."
run "git clone https://github.com/${ORG}/claude_code_agents .claude/_upstream/agents-repo"
if ! $DRY_RUN; then
    cd .claude/_upstream/agents-repo
    run "git remote add upstream https://github.com/wshobson/agents"
    cd ../../..
else
    info "Would add upstream remote for agents"
fi

info "Cloning commands..."
run "git clone https://github.com/${ORG}/claude_code_commands .claude/_upstream/commands-repo"
if ! $DRY_RUN; then
    cd .claude/_upstream/commands-repo
    run "git remote add upstream https://github.com/wshobson/commands"
    cd ../../..
else
    info "Would add upstream remote for commands"
fi

# Set up symlinks from .claude/agents and .claude/commands to _upstream repos
if ! $DRY_RUN; then
    ln -sfn _upstream/agents-repo .claude/agents
    ln -sfn _upstream/commands-repo .claude/commands
    ok "Symlinks created: .claude/agents → _upstream/agents-repo, .claude/commands → _upstream/commands-repo"
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

    # Update container name
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
        # Escape forward slashes for sed
        ESCAPED_HOST=$(echo "$HOST_PATH" | sed 's/\//\\\//g')
        MOUNT_LINE="    \"source=${HOST_PATH},target=/workspace/src/${PROJECT},type=bind,consistency=delegated\""

        # Insert the bind mount after the existing mounts array opening entries
        # Find the last mount line and append after it
        if [[ "$HOST_OS" == "mac" ]]; then
            sed -i '' "/\"source=claude-code-config/a\\
${MOUNT_LINE}" "$DEVCONTAINER"
        else
            sed -i "/\"source=claude-code-config/a\\
${MOUNT_LINE}" "$DEVCONTAINER"
        fi

        # Add comma to the config mount line (it's no longer the last entry)
        if [[ "$HOST_OS" == "mac" ]]; then
            sed -i '' "s|\"source=claude-code-config-${PROJECT},target=/home/node/.claude,type=volume\"|\"source=claude-code-config-${PROJECT},target=/home/node/.claude,type=volume\",|" "$DEVCONTAINER"
        else
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

# ─── Step 6: Create GitHub repo ──────────────────────────────────────────────
echo ""
info "Setting up GitHub repo ${INSTANCE_REPO}..."

if ! $DRY_RUN; then
    # Check if repo already exists
    if gh repo view "$INSTANCE_REPO" &>/dev/null 2>&1; then
        warn "GitHub repo ${INSTANCE_REPO} already exists, skipping creation"
    else
        info "Creating GitHub repo ${INSTANCE_REPO}..."
        gh repo create "$INSTANCE_REPO" --private --description "DCA instance for ${PROJECT}" || {
            err "Failed to create GitHub repo. You may need to create it manually."
            warn "Continuing with local setup..."
        }
        ok "GitHub repo created"
    fi
else
    info "Would create GitHub repo: ${INSTANCE_REPO} (private)"
fi

# ─── Step 7: Configure git remotes ───────────────────────────────────────────
echo ""
info "Configuring git remotes..."

if ! $DRY_RUN; then
    git remote set-url origin "https://github.com/${INSTANCE_REPO}.git"
    git remote add upstream "https://github.com/${TEMPLATE_REPO}.git" 2>/dev/null || \
        git remote set-url upstream "https://github.com/${TEMPLATE_REPO}.git"

    ok "Remotes configured:"
    git remote -v
else
    info "Would set origin  → https://github.com/${INSTANCE_REPO}.git"
    info "Would set upstream → https://github.com/${TEMPLATE_REPO}.git"
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

    info "Pushing to origin..."
    git push -u origin master || {
        warn "Push failed. You may need to push manually: git push -u origin master"
    }
    ok "Pushed to ${INSTANCE_REPO}"
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
