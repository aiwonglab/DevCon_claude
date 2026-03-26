---
model: claude-sonnet-4-6
---

# Sync Template Updates and Manage Sub-repos

Set up a workspace that tracks an upstream DevCon template repo while pushing project-specific code to its own repo. The workspace receives template infrastructure updates (`.devcontainer/`, `.claude/`, `CLAUDE.md` skeleton) and writes project code (`src/`, `output/`, `data/`) back to its own origin.

## Architecture

```
aiwonglab/DevCon_claude (template)        ← "upstream" remote
    │
    │  git fetch upstream && git merge upstream/main
    ▼
workspace/                                ← Your project's Git repo
    │   origin → synappse-me/MyProject    ← "origin" remote (project-specific)
    │
    ├── .devcontainer/        ← From template, receives updates
    ├── .claude/
    │   ├── _upstream/        ← Git-ignored; agent/command sub-repos (separate concern)
    │   ├── agents/           ← Curated symlinks (git-ignored)
    │   ├── commands/         ← Curated symlinks (git-ignored) + this skill file
    │   ├── curate.sh         ← From template, receives updates
    │   └── *.md              ← Prompt templates from template
    ├── CLAUDE.md             ← Starts from template, customized per project
    ├── .gitignore            ← Merged: template patterns + project patterns
    ├── src/                  ← PROJECT-SPECIFIC: pushed to origin
    ├── data/                 ← PROJECT-SPECIFIC: pushed to origin
    ├── output/               ← PROJECT-SPECIFIC: pushed to origin
    └── tests/                ← PROJECT-SPECIFIC: pushed to origin
```

## Two Layers

This skill manages **two separate concerns**:

### Layer 1: Workspace ↔ Template (git remotes on the workspace repo itself)
- `origin` → your project repo (e.g., `synappse-me/SCCM_CCC_2026`)
- `upstream` → the template repo (e.g., `aiwonglab/DevCon_claude`)
- Template updates flow via `git fetch upstream && git merge upstream/main`
- Project code flows via `git push origin`
- Conflicts only in shared files (`.devcontainer/`, `CLAUDE.md`) — resolve once

### Layer 2: Agent/Command Sub-repos (nested git clones, git-ignored)
- `.claude/_upstream/agents-repo` → clone of `wshobson/agents` (or your fork)
- `.claude/_upstream/commands-repo` → clone of `wshobson/commands` (or your fork)
- Managed via `curate.sh` symlinks
- Completely independent of the workspace git history

## What This Skill Does

When invoked, detect the current state and perform the appropriate action.

### Step 1: Diagnose Current State

Run these checks and report findings:
```bash
# Check workspace remotes
git remote -v

# Check if upstream exists
git remote get-url upstream 2>/dev/null

# Check sub-repo state
ls -la .claude/_upstream/ 2>/dev/null

# Check .gitignore coverage
grep -n '_upstream\|\.claude/agents\|\.claude/commands' .gitignore
```

Present a summary like:
```
Workspace Template Downstream Status:
  origin:   synappse-me/SCCM_CCC_2026 ✅
  upstream: (not configured) ❌
  Sub-repos: agents-repo ✅, commands-repo ✅
  .gitignore: sub-repos excluded ✅
```

### Step 2: Based on State, Offer Actions

#### Action A: Add Upstream Remote (no `upstream` remote exists)

Ask the user for the template repo URL:
- Default: `https://github.com/aiwonglab/DevCon_claude`

Then:
1. `git remote add upstream <template_url>`
2. `git fetch upstream`
3. Show divergence: `git log --oneline upstream/main..HEAD` (project commits not in template)
4. Show available updates: `git log --oneline HEAD..upstream/main` (template commits not in project)
5. Ask if user wants to merge now

#### Action B: Pull Template Updates (`upstream` remote exists)

1. `git fetch upstream`
2. Show what's new: `git log --oneline HEAD..upstream/main`
3. If updates available, ask user to confirm merge
4. `git merge upstream/main` (NOT `--ff-only` since histories have diverged)
5. If conflicts arise:
   - List conflicted files
   - Explain: template files (`.devcontainer/`, `.claude/`) — usually accept upstream
   - Project files (`src/`, `CLAUDE.md`) — usually keep ours
   - Help resolve interactively
6. After merge, show result: `git log --oneline -5`

#### Action C: Setup Sub-repos (no `.claude/_upstream/` exists)

Ask the user for:
1. **Agents repo URL** (default: `https://github.com/wshobson/agents`)
2. **Commands repo URL** (default: `https://github.com/wshobson/commands`)
3. **Fork URLs** (optional — set fork as `origin`, original as `upstream` on sub-repos)

Then:
1. `mkdir -p .claude/_upstream`
2. Clone repos into `.claude/_upstream/agents-repo` and `.claude/_upstream/commands-repo`
3. Set up fork remotes if provided
4. Run `curate.sh setup` if it exists
5. Verify `.gitignore` has:
   ```
   .claude/_upstream/
   .claude/agents
   .claude/commands
   ```

#### Action D: Update Sub-repos (`.claude/_upstream/` exists)

1. Pull latest in each sub-repo: `git -C .claude/_upstream/<repo> pull --ff-only`
2. If sub-repos have forks with `upstream` remote:
   - `git fetch upstream && git merge upstream/main --ff-only`
3. Report what changed
4. Symlinks automatically reflect updates

#### Action E: Full Setup (fresh workspace, nothing configured)

Combine A + C:
1. Set up upstream remote for template
2. Clone sub-repos
3. Run curate.sh
4. Verify .gitignore
5. Show full status

### Step 3: Show Final Status

After any action, show:
```
Template Downstream Status:
  origin:   synappse-me/SCCM_CCC_2026
  upstream: aiwonglab/DevCon_claude
  Last template sync: 2026-03-08 (3 commits behind)
  Sub-repos:
    agents-repo:   main @ abc1234 (wshobson/agents)
    commands-repo: main @ def5678 (wshobson/commands)
  Symlinks: 13 commands, 19 plugins
```

## Merge Strategy for Template Updates

When merging template updates into a project repo:

**Files that should generally accept upstream (template) changes:**
- `.devcontainer/Dockerfile`
- `.devcontainer/devcontainer.json` (except `name` and volume source names)
- `.devcontainer/*.sh` (setup scripts)
- `.claude/curate.sh`
- `.claude/commit-prompt.md`, `.claude/commit-prompt-template.md`
- `.claude/git-init-project-prompt.md`
- `.gitattributes`

**Files that should generally keep project (ours) changes:**
- `CLAUDE.md` (customized per project)
- `src/` (project code — template doesn't touch this)
- `data/`, `output/`, `tests/` (project-specific)
- `.gitignore` (merged — keep both template and project patterns)

**Files that need manual merge:**
- `.devcontainer/devcontainer.json` — keep project name/volumes, accept new features
- `CLAUDE.md` — may want new template sections while keeping project customizations
- `pyproject.toml` — if template adds dependencies

## Important Rules

1. **Never re-init the workspace git repo** — only add/manage remotes
2. **Never force-push** — always merge, never rebase against upstream
3. **Ask before merging** — show the user what will change first
4. **Conflicts are normal** — help resolve them, don't avoid the merge
5. **Sub-repos are independent** — their git history is separate from the workspace
6. **The `_upstream/` directory is git-ignored** — sub-repos are local clones only
7. **Symlinks are relative** — they work across machines
8. **Ask before cloning** — confirm repo URLs with the user

## Setting Up a New Project from the Template

When a user wants to create a brand new project from DevCon_claude:

1. Fork or use GitHub "Use this template" to create project repo
2. Clone the project repo
3. `git remote add upstream <DevCon_claude_URL>`
4. Run this skill to set up sub-repos and verify everything
5. Start coding in `src/`

The `setup_project.sh` script in `.devcontainer/` handles the initial clone + sub-repo setup.
This skill handles ongoing maintenance and template syncing after that.
