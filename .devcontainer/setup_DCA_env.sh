#!/bin/bash

# Check if folder name argument is provided
if [ -z "$1" ]; then
    echo "Error: Please provide a folder name for the main repository"
    echo "Usage: ./setup_DCA_env.sh <folder_name>"
    exit 1
fi

FOLDER_NAME="$1"

# Clone the main repository
echo "Cloning main repository to ${FOLDER_NAME}..."
git clone https://github.com/aiwonglab/DevCon_claude "${FOLDER_NAME}"

if [ $? -ne 0 ]; then
    echo "Error: Failed to clone main repository"
    exit 1
fi

# Navigate to the cloned repository
cd "${FOLDER_NAME}" || exit 1
echo "Current directory: $(pwd)"

# Create .claude directory if it doesn't exist
mkdir -p .claude

# Clone agents repository
echo "Cloning agents repository to .claude/agents..."
git clone https://github.com/aiwonglab/claude_code_agents .claude/agents

if [ $? -ne 0 ]; then
    echo "Error: Failed to clone agents repository"
    exit 1
fi

# Set up upstream remote for agents
echo "Setting up upstream remote for agents..."
cd .claude/agents
git remote add upstream https://github.com/wshobson/agents
cd ../..

# Clone commands repository
echo "Cloning commands repository to .claude/commands..."
git clone https://github.com/aiwonglab/claude_code_commands .claude/commands

if [ $? -ne 0 ]; then
    echo "Error: Failed to clone commands repository"
    exit 1
fi

# Set up upstream remote for commands
echo "Setting up upstream remote for commands..."
cd .claude/commands
git remote add upstream https://github.com/wshobson/commands
cd ../..

# Create src subfolder
echo "Creating src subfolder..."
mkdir -p src
mkdir -p data

# Update devcontainer name if it exists
if [ -f .devcontainer/devcontainer.json ]; then
    echo "Updating devcontainer name to DCA: ${FOLDER_NAME}..."
    # sed -i "s/\"name\": \".*\"/\"name\": \"DCA: ${FOLDER_NAME}\"/" .devcontainer/devcontainer.json
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/\"name\": \".*\"/\"name\": \"DCA: ${FOLDER_NAME}\"/" .devcontainer/devcontainer.json
    else
        sed -i "s/\"name\": \".*\"/\"name\": \"DCA: ${FOLDER_NAME}\"/" .devcontainer/devcontainer.json
    fi
fi

echo "All repositories cloned successfully!"
echo "Main repository: ${FOLDER_NAME}"
echo "Agents: ${FOLDER_NAME}/.claude/agents"
echo "Commands: ${FOLDER_NAME}/.claude/commands"