#!/bin/bash

# Migration script to update existing DevCons to use aiwonglab repos
# Handles various existing states and preserves custom changes

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  DevCon Migration to aiwonglab Repos                      ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo ""

# Ensure we're in a git repository
if [ ! -d ".git" ]; then
    echo -e "${RED}❌ Error: Not in a git repository root${NC}"
    echo "Please run this script from your DevCon workspace root"
    exit 1
fi

WORKSPACE_ROOT=$(pwd)

# Function to backup a directory
backup_directory() {
    local dir=$1
    local backup_name="${dir}.backup.$(date +%Y%m%d_%H%M%S)"

    if [ -d "$dir" ]; then
        echo -e "${YELLOW}  Creating backup: ${backup_name}${NC}"
        cp -r "$dir" "$backup_name"
        return 0
    fi
    return 1
}

# Function to check if directory is a git repo
is_git_repo() {
    local dir=$1
    [ -d "${dir}/.git" ]
}

# Function to get git remote url
get_remote_url() {
    local dir=$1
    cd "$dir" && git remote get-url origin 2>/dev/null || echo ""
}

# Function to check for uncommitted changes
has_uncommitted_changes() {
    local dir=$1
    cd "$dir" && [ -n "$(git status -s)" ]
}

# Function to migrate agents repository
migrate_agents() {
    echo -e "${BLUE}═══ Migrating Agents Repository ═══${NC}"

    local agents_path="${WORKSPACE_ROOT}/.claude/agents"

    # Case 1: No agents directory
    if [ ! -d "$agents_path" ]; then
        echo "  No existing agents directory found"
        echo "  Cloning from aiwonglab/claude_code_agents..."
        mkdir -p "${WORKSPACE_ROOT}/.claude"
        git clone https://github.com/aiwonglab/claude_code_agents "$agents_path"
        cd "$agents_path"
        git remote add upstream https://github.com/wshobson/agents
        echo -e "${GREEN}✅ Agents cloned and configured${NC}"
        cd "$WORKSPACE_ROOT"
        return 0
    fi

    # Case 2: Directory exists but not a git repo
    if ! is_git_repo "$agents_path"; then
        echo "  Agents directory exists but is not a git repository"
        backup_directory "$agents_path"
        rm -rf "$agents_path"
        echo "  Cloning from aiwonglab/claude_code_agents..."
        git clone https://github.com/aiwonglab/claude_code_agents "$agents_path"
        cd "$agents_path"
        git remote add upstream https://github.com/wshobson/agents
        echo -e "${GREEN}✅ Agents migrated (old version backed up)${NC}"
        cd "$WORKSPACE_ROOT"
        return 0
    fi

    # Case 3: Is a git repo
    cd "$agents_path"
    local current_remote=$(get_remote_url "$agents_path")

    echo "  Current remote: $current_remote"

    # Check for uncommitted changes
    if has_uncommitted_changes "$agents_path"; then
        echo -e "${YELLOW}⚠️  Warning: Uncommitted changes detected${NC}"
        git status -s
        echo ""
        read -p "  Commit changes before migration? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git add .
            git commit -m "Save local changes before migration to aiwonglab"
        else
            echo -e "${RED}❌ Migration aborted. Please commit or stash changes first.${NC}"
            cd "$WORKSPACE_ROOT"
            return 1
        fi
    fi

    # Case 3a: Already pointing to aiwonglab
    if [[ "$current_remote" == *"aiwonglab/claude_code_agents"* ]]; then
        echo -e "${GREEN}✅ Already configured for aiwonglab${NC}"

        # Check if upstream exists
        if ! git remote get-url upstream >/dev/null 2>&1; then
            echo "  Adding upstream remote..."
            git remote add upstream https://github.com/wshobson/agents
            echo -e "${GREEN}✅ Upstream remote added${NC}"
        fi
        cd "$WORKSPACE_ROOT"
        return 0
    fi

    # Case 3b: Pointing to wshobson - migrate to aiwonglab
    if [[ "$current_remote" == *"wshobson/agents"* ]]; then
        echo "  Migrating from wshobson to aiwonglab..."

        # Rename origin to upstream
        git remote rename origin upstream

        # Add aiwonglab as new origin
        git remote add origin https://github.com/aiwonglab/claude_code_agents

        # Try to push to new origin (might fail if repo doesn't exist or needs auth)
        echo "  Attempting to push to new origin..."
        if git push -u origin main 2>/dev/null; then
            echo -e "${GREEN}✅ Pushed to aiwonglab successfully${NC}"
        else
            echo -e "${YELLOW}⚠️  Could not push to aiwonglab (may need authentication)${NC}"
            echo "  You can push manually later with: cd .claude/agents && git push origin main"
        fi

        echo -e "${GREEN}✅ Agents migrated to aiwonglab${NC}"
        cd "$WORKSPACE_ROOT"
        return 0
    fi

    # Case 3c: Unknown remote
    echo -e "${YELLOW}⚠️  Unknown remote: $current_remote${NC}"
    echo "  This appears to be a custom fork. Skipping migration."
    cd "$WORKSPACE_ROOT"
    return 0
}

# Function to migrate commands repository
migrate_commands() {
    echo ""
    echo -e "${BLUE}═══ Migrating Commands Repository ═══${NC}"

    local commands_path="${WORKSPACE_ROOT}/.claude/commands"

    # Case 1: No commands directory
    if [ ! -d "$commands_path" ]; then
        echo "  No existing commands directory found"
        echo "  Cloning from aiwonglab/claude_code_commands..."
        mkdir -p "${WORKSPACE_ROOT}/.claude"
        git clone https://github.com/aiwonglab/claude_code_commands "$commands_path"
        cd "$commands_path"
        git remote add upstream https://github.com/wshobson/commands
        echo -e "${GREEN}✅ Commands cloned and configured${NC}"
        cd "$WORKSPACE_ROOT"
        return 0
    fi

    # Case 2: Directory exists but not a git repo
    if ! is_git_repo "$commands_path"; then
        echo "  Commands directory exists but is not a git repository"
        backup_directory "$commands_path"
        rm -rf "$commands_path"
        echo "  Cloning from aiwonglab/claude_code_commands..."
        git clone https://github.com/aiwonglab/claude_code_commands "$commands_path"
        cd "$commands_path"
        git remote add upstream https://github.com/wshobson/commands
        echo -e "${GREEN}✅ Commands migrated (old version backed up)${NC}"
        cd "$WORKSPACE_ROOT"
        return 0
    fi

    # Case 3: Is a git repo
    cd "$commands_path"
    local current_remote=$(get_remote_url "$commands_path")

    echo "  Current remote: $current_remote"

    # Check for uncommitted changes
    if has_uncommitted_changes "$commands_path"; then
        echo -e "${YELLOW}⚠️  Warning: Uncommitted changes detected${NC}"
        git status -s
        echo ""
        read -p "  Commit changes before migration? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git add .
            git commit -m "Save local changes before migration to aiwonglab"
        else
            echo -e "${RED}❌ Migration aborted. Please commit or stash changes first.${NC}"
            cd "$WORKSPACE_ROOT"
            return 1
        fi
    fi

    # Case 3a: Already pointing to aiwonglab
    if [[ "$current_remote" == *"aiwonglab/claude_code_commands"* ]]; then
        echo -e "${GREEN}✅ Already configured for aiwonglab${NC}"

        # Check if upstream exists
        if ! git remote get-url upstream >/dev/null 2>&1; then
            echo "  Adding upstream remote..."
            git remote add upstream https://github.com/wshobson/commands
            echo -e "${GREEN}✅ Upstream remote added${NC}"
        fi
        cd "$WORKSPACE_ROOT"
        return 0
    fi

    # Case 3b: Pointing to wshobson - migrate to aiwonglab
    if [[ "$current_remote" == *"wshobson/commands"* ]]; then
        echo "  Migrating from wshobson to aiwonglab..."

        # Rename origin to upstream
        git remote rename origin upstream

        # Add aiwonglab as new origin
        git remote add origin https://github.com/aiwonglab/claude_code_commands

        # Try to push to new origin
        echo "  Attempting to push to new origin..."
        if git push -u origin main 2>/dev/null; then
            echo -e "${GREEN}✅ Pushed to aiwonglab successfully${NC}"
        else
            echo -e "${YELLOW}⚠️  Could not push to aiwonglab (may need authentication)${NC}"
            echo "  You can push manually later with: cd .claude/commands && git push origin main"
        fi

        echo -e "${GREEN}✅ Commands migrated to aiwonglab${NC}"
        cd "$WORKSPACE_ROOT"
        return 0
    fi

    # Case 3c: Unknown remote
    echo -e "${YELLOW}⚠️  Unknown remote: $current_remote${NC}"
    echo "  This appears to be a custom fork. Skipping migration."
    cd "$WORKSPACE_ROOT"
    return 0
}

# Main migration flow
echo "Starting migration process..."
echo "Workspace: $WORKSPACE_ROOT"
echo ""

# Migrate agents
if ! migrate_agents; then
    echo -e "${RED}❌ Agents migration failed${NC}"
    exit 1
fi

# Migrate commands
if ! migrate_commands; then
    echo -e "${RED}❌ Commands migration failed${NC}"
    exit 1
fi

# Summary
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Migration Summary                                         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

cd "${WORKSPACE_ROOT}/.claude/agents" 2>/dev/null && {
    echo "Agents Repository:"
    echo "  Origin:   $(git remote get-url origin 2>/dev/null || echo 'Not configured')"
    echo "  Upstream: $(git remote get-url upstream 2>/dev/null || echo 'Not configured')"
    echo ""
}

cd "${WORKSPACE_ROOT}/.claude/commands" 2>/dev/null && {
    echo "Commands Repository:"
    echo "  Origin:   $(git remote get-url origin 2>/dev/null || echo 'Not configured')"
    echo "  Upstream: $(git remote get-url upstream 2>/dev/null || echo 'Not configured')"
    echo ""
}

cd "$WORKSPACE_ROOT"

echo -e "${GREEN}🎉 Migration completed successfully!${NC}"
echo ""
echo "Next steps:"
echo "  1. Verify your agents and commands are working"
echo "  2. To sync with wshobson's updates, run: /workflows:sync-upstream"
echo "  3. To push your custom changes, run: git push origin main in each repo"
