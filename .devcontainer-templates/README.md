# DevCon_claude

Devcontainer for Claude, based on Anthropic's example at (https://github.com/anthropics/claude-code/tree/main)

- Devcontainer
- uv and pixi (though Pixi seems finicky)

## DevContainer Templates

The `.devcontainer-templates/` directory contains pre-configured templates for different development environments:

### Available Templates

- **claude-linux-base**: Basic Linux environment with Python and uv
- **claude-linux-cuda**: Linux environment with CUDA support for GPU-accelerated workloads
- **claude-wsl-base**: Windows Subsystem for Linux (WSL) basic environment
- **claude-wsl-base-dotnet**: WSL environment with .NET support
- **claude-wsl-cuda**: WSL environment with CUDA support

Each template includes:

- `devcontainer.json`: Container configuration with postCreateCommand setup
- `Dockerfile`: Container image definition
- `CLAUDE.md`: Project-specific instructions and guidelines

The devcontainer configuration automatically runs initialization scripts:
- **init-firewall**: Configures network security settings
- **init-dev-tools**: Installs and configures development tools
- **postCreateCommand**: Sets up the development environment after container creation
