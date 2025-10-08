# DevCon_claude

Development container for Claude Code with infrastructure management and research project separation.

Based on [Anthropic's Claude Code example](https://github.com/anthropics/claude-code/tree/main).

## Quick Start

### For New Projects

```bash
bash .devcontainer/setup_DCA_env.sh my-project-name
```

This creates a complete workspace with:
- Claude Code agents (from `aiwonglab/claude_code_agents`)
- Claude Code commands (from `aiwonglab/claude_code_commands`)
- Pre-configured directory structure for research work
- Upstream remotes to sync with `wshobson` updates

### For Existing Projects

Migrate existing DevCon workspaces to the new structure:

```bash
cd /path/to/existing/workspace
bash .devcontainer/migrate_to_aiwonglab.sh
```

See [MIGRATION.md](.devcontainer/MIGRATION.md) for details.

## Repository Structure

```
/workspace/
├── .devcontainer/          # Container configuration
│   ├── setup_DCA_env.sh   # Setup script for new projects
│   ├── migrate_to_aiwonglab.sh  # Migration script
│   └── MIGRATION.md       # Migration documentation
├── .claude/
│   ├── agents/            # Git submodule: claude_code_agents
│   └── commands/          # Git submodule: claude_code_commands
├── src/                   # Your research code (gitignored)
├── data/                  # Your data files (gitignored)
├── output/                # Generated outputs (gitignored)
└── results/               # Research results (gitignored)
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

Uses forked repositories with upstream tracking:

- **Origin**: `aiwonglab/claude_code_agents` and `aiwonglab/claude_code_commands` (your forks)
- **Upstream**: `wshobson/agents` and `wshobson/commands` (originals)

Sync upstream updates:
```bash
/workflows:sync-upstream
```

Or manually:
```bash
cd .claude/agents
git fetch upstream
git merge upstream/main
git push origin main
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
- **Git**: Infrastructure and research repos managed independently
- **Docker**: DevContainer for consistent environments
- **Claude Code**: AI-powered development with specialized agents

## Workflows

### Initial Setup

1. Clone this repo OR run setup script
2. Open in VS Code with Dev Containers extension
3. Container builds and initializes automatically
4. Agents and commands are cloned and configured
5. Start working in `src/` directory

### Adding Research Projects

```bash
cd src/
git clone https://github.com/yourorg/research-project .
# OR
git init
# Start coding
```

Your research repo is completely independent of infrastructure.

### Updating Infrastructure

```bash
git pull origin master  # Update DevCon infrastructure
```

Research code in `src/` is unaffected.

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

- **Agents**: [aiwonglab/claude_code_agents](https://github.com/aiwonglab/claude_code_agents) (fork of wshobson/agents)
- **Commands**: [aiwonglab/claude_code_commands](https://github.com/aiwonglab/claude_code_commands) (fork of wshobson/commands)
- **Upstream Agents**: [wshobson/agents](https://github.com/wshobson/agents)
- **Upstream Commands**: [wshobson/commands](https://github.com/wshobson/commands)

## License

MIT License (inherited from Anthropic's example)
