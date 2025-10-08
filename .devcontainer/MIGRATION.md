# Migrating Existing DevCons to aiwonglab Repos

This guide helps you migrate existing DevCon workspaces from wshobson's repos to aiwonglab's fork while preserving custom changes.

## Quick Start

```bash
cd /path/to/your/devcon/workspace
bash .devcontainer/migrate_to_aiwonglab.sh
```

## What the Migration Does

The script handles all common scenarios:

### Scenario 1: No `.claude/agents` or `.claude/commands`
- Clones from `aiwonglab/claude_code_agents`
- Clones from `aiwonglab/claude_code_commands`
- Sets up upstream remotes to wshobson

### Scenario 2: Non-git directories exist
- Backs up existing directories (timestamped)
- Clones fresh from aiwonglab repos
- Configures upstream remotes

### Scenario 3: Git repos pointing to wshobson
- Renames `origin` → `upstream` (wshobson)
- Adds new `origin` → aiwonglab
- Preserves all local commits
- Attempts to push to new origin

### Scenario 4: Already on aiwonglab
- Verifies configuration
- Adds upstream remote if missing
- No changes needed

## What Gets Preserved

✅ All local commits and custom agents/commands
✅ Git history
✅ Branch structure
✅ Uncommitted changes (after confirmation)

## Manual Steps After Migration

1. **Push to your fork** (if auto-push failed):
   ```bash
   cd .claude/agents
   git push origin main

   cd ../commands
   git push origin main
   ```

2. **Sync with wshobson's updates**:
   ```bash
   /workflows:sync-upstream
   ```

## For New DevCons

Use the updated setup script instead:
```bash
bash .devcontainer/setup_DCA_env.sh my-project-name
```

This automatically:
- Clones from aiwonglab repos
- Sets up upstream remotes to wshobson
- Ready to go immediately

## Troubleshooting

**Authentication errors when pushing:**
- Set up GitHub authentication (SSH keys or token)
- Push manually after configuring auth

**Uncommitted changes warning:**
- Commit your changes when prompted
- Or stash them: `git stash`
- Migration preserves your work

**Merge conflicts:**
- If you have diverged significantly from wshobson
- Resolve conflicts manually
- See `/workflows:sync-upstream` for guidance

## Verification

After migration, verify remotes:
```bash
cd .claude/agents && git remote -v
cd ../commands && git remote -v
```

Should show:
```
origin    https://github.com/aiwonglab/claude_code_agents (fetch)
origin    https://github.com/aiwonglab/claude_code_agents (push)
upstream  https://github.com/wshobson/agents (fetch)
upstream  https://github.com/wshobson/agents (push)
```
