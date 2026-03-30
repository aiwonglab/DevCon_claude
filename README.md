# DevCon Template

Devcontainer template for creating project-specific development environments with Claude Code.

> **This is the template repo.** You don't work in this repo directly. Instead, use `setup_project.sh` to create project instances like `DCA_praxis`, `DCA_livelingual`, etc. Each instance is its own GitHub repo that can pull template updates via `git pull upstream master`.

Based on [Anthropic's Claude Code example](https://github.com/anthropics/claude-code/tree/main).

## Creating a New Project Instance

One-liner (no need to clone the template first):
```bash
curl -fsSL https://raw.githubusercontent.com/aiwonglab/DevCon_claude/master/.devcontainer/setup_project.sh \
  | bash -s -- <project-name>
```

Or if you already have the repo cloned:
```bash
bash .devcontainer/setup_project.sh <project-name>
```

This clones DevCon_claude, then configures it as a standalone instance:

- Creates GitHub repo `<org>/DCA_<project>` (private, requires `gh`)
- Sets container name to `DCA: <project>` with isolated volumes
- Optionally adds a bind mount for host project source
- Clones Claude Code agents and commands from [wshobson/agents](https://github.com/wshobson/agents) and [wshobson/commands](https://github.com/wshobson/commands)
- Sets git remotes: `origin` → instance repo, `upstream` → this template
- Commits and pushes the initial configuration

If `gh` isn't available, local setup completes and you can add the GitHub repo later:
```bash
bash setup_project.sh <project-name> --github-only
```

### Examples

```bash
# Create DCA_praxis with defaults
bash .devcontainer/setup_project.sh praxis

# Non-interactive with bind mount
bash .devcontainer/setup_project.sh praxis --mount C:/git/praxis

# Different org
bash .devcontainer/setup_project.sh praxis --org other-org

# Use custom agent/command forks instead of wshobson defaults
bash .devcontainer/setup_project.sh praxis \
  --agents myorg/my-agents --commands myorg/my-commands

# Preview what would happen
bash .devcontainer/setup_project.sh praxis --dry-run

# Add GitHub repo to an existing instance
bash .devcontainer/setup_project.sh praxis --github-only
```

### Pulling Template Updates into an Instance

```bash
cd DCA_praxis/
git fetch upstream master
git merge upstream/master
```

### Migrating Existing Projects

```bash
cd /path/to/existing/workspace
bash .devcontainer/migrate_to_aiwonglab.sh
```

See [MIGRATION.md](.devcontainer/MIGRATION.md) for details. (Legacy migration script — may need updating for your org.)

## Repository Structure

```
/workspace/
├── .devcontainer/
│   ├── setup_project.sh        # Instance creation script
│   ├── migrate_to_aiwonglab.sh # Legacy migration script
│   └── MIGRATION.md
├── .claude/
│   ├── _upstream/         # Git-ignored; agent/command sub-repo clones
│   │   ├── agents-repo/   # Clone of claude_code_agents
│   │   └── commands-repo/ # Clone of claude_code_commands
│   ├── agents/            # Symlink → _upstream/agents-repo
│   └── commands/          # Symlink → _upstream/commands-repo
├── src/                   # Project source (gitignored, bind-mounted)
├── data/                  # Data files (gitignored)
├── output/                # Generated outputs (gitignored)
└── results/               # Results (gitignored)
```

## Design Philosophy

### Infrastructure vs Research Separation

This repository is **infrastructure only**. Your research projects live independently:

- **Infrastructure** (this repo): DevContainer configs, templates, setup scripts
- **Research** (your repos): Goes in `src/`, `data/`, `output/`, `results/`

Benefits:
- Update infrastructure without touching research code
- Easily switch between research projects
- Keep infrastructure clean and reusable
- Research repos remain independent

### Agents and Commands

By default, agents and commands are cloned from:

- [wshobson/agents](https://github.com/wshobson/agents)
- [wshobson/commands](https://github.com/wshobson/commands)

Use `--agents` and `--commands` flags to point to your own forks.

Sync updates:
```bash
cd .claude/_upstream/agents-repo
git pull origin main
```

## Key Features

### Strategic Agents

New specialized agents for startup planning:

- **product-strategist**: Product vision, roadmaps, go-to-market strategies
- **technical-strategist**: Technology roadmaps, architectural evolution

### Startup Workflows

- **`/workflows:idea-validator`**: Quick validation (market, tech, business)
- **`/workflows:startup-analyzer`**: Comprehensive 10-phase strategic analysis
- **`/workflows:sync-upstream`**: Sync with wshobson's latest updates

### Development Tools

- **`/tools:sync-repos`**: Quick bash script for automated syncing

## DevContainer Templates

The `.devcontainer-templates/` directory contains pre-configured templates:

### Linux Templates
- **claude-linux-base**: Basic Linux environment with Python and uv
- **claude-linux-conda**: Linux with Conda package management
- **claude-linux-cuda**: Linux with CUDA support for GPU workloads

### WSL Templates
- **claude-wsl-base**: Windows Subsystem for Linux basic environment
- **claude-wsl-base-dotnet**: WSL with .NET support
- **claude-wsl-cuda**: WSL with CUDA support

Each template includes:
- `devcontainer.json`: Container configuration
- `Dockerfile`: Image definition
- `CLAUDE.md`: Project-specific guidelines

### Initialization Scripts

Templates automatically run:
- **init-firewall.sh**: Network security configuration
- **install-dev-tools.sh**: Development tools setup
- **postCreateCommand.sh**: Environment initialization

## Technology Stack

- **Python**: Managed with `uv` (fast, modern package manager)
- **R**: Planned via `pixi` (multi-language package manager) — not yet supported
- **Git**: Infrastructure and research repos managed independently
- **Docker**: DevContainer for consistent environments
- **Claude Code**: Development with specialized agents and slash commands

## Workflows

### Creating a New Instance

1. Run `bash .devcontainer/setup_project.sh <name>`
2. Open the created `DCA_<name>/` directory in VS Code
3. Reopen in container (Dev Containers extension)
4. Start working in `/workspace/src/<name>/`

### Pulling Template Updates

From inside an instance:
```bash
git fetch upstream master
git merge upstream/master
```

### Syncing Agents/Commands

```bash
/workflows:sync-upstream  # Interactive workflow
# OR
/tools:sync-repos        # Automated script
```

## Contributing

This is infrastructure for research work. Contributions welcome for:
- DevContainer improvements
- New templates
- Setup/migration script enhancements
- Documentation updates

Research projects should live in their own repositories.

## Related Repositories

- **Agents**: [wshobson/agents](https://github.com/wshobson/agents) — Claude Code agent definitions
- **Commands**: [wshobson/commands](https://github.com/wshobson/commands) — Claude Code slash commands

## License

MIT License (inherited from Anthropic's example)
