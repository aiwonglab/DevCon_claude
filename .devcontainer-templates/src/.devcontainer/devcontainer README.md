This is reorganized to keep the base files into each devcontainer so that things are only written once (e..g, init-firewall, init-dev-tools, etc)

templates/
├── src/
│ ├── .devcontainer/
│ │ ├── init-firewall.sh
│ │ ├── devcontainer-template.json
│ │ └── devcontainer README.md/
│ ├── claude-linux-base/
│ │ ├── devcontainer-template.json
│ │ └── .devcontainer/
│ ├── claude-linux-cuda/
│ │ ├── devcontainer-template.json
│ │ └── .devcontainer/
│ └── claude-wsl-base/ # only for
│ │ ├── devcontainer-template.json
│ │ └── .devcontainer/
│ ├── devcontainer-template.json
│ └── .devcontainer/
└── README.md
