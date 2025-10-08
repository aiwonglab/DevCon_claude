FROM node:20
# FROM nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04

ARG TZ
ENV TZ="$TZ"

# Install basic development tools and iptables/ipset
RUN apt update && apt install -y less \
  git \
  procps \
  sudo \
  fzf \
  zsh \
  man-db \
  unzip \
  gnupg2 \
  gh \
  iptables \
  ipset \
  iproute2 \
  dnsutils \
  aggregate \
  nano \
  jq \
  tmux \
  wget \
  curl

# Install Node.js and Claude in one step to ensure npm is available
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
  apt install -y nodejs && \
  npm install -g @anthropic-ai/claude-code

# Fix zsh permissions and fzf issues
RUN chmod -R 755 /usr/local/share/zsh/ && \
  chown -R root:root /usr/local/share/zsh/ && \
  mkdir -p /usr/share/doc/fzf/examples && \
  find /usr/share/fzf -name "*.zsh" -exec cp {} /usr/share/doc/fzf/examples/ \; 2>/dev/null || true

# Add ZSH_DISABLE_COMPFIX to environment
ENV ZSH_DISABLE_COMPFIX=true

# # uncomment the following lines if you're not using a node:18 image
# # Create node user (matching the official Node.js image)
# RUN groupadd --gid 1000 node && \
#   useradd --uid 1000 --gid node --shell /bin/bash --create-home node

# Create directories and set permissions BEFORE switching to node user
RUN mkdir -p /usr/local/share/npm-global && \
  chown -R node:node /usr/local/share

# Create minimal fzf files if they don't exist (as root)
RUN mkdir -p /usr/share/doc/fzf/examples && \
  echo '# FZF key bindings' > /usr/share/doc/fzf/examples/key-bindings.zsh && \
  echo '# FZF completion' > /usr/share/doc/fzf/examples/completion.zsh && \
  chmod 644 /usr/share/doc/fzf/examples/*.zsh

# NOW create the .zshrc file AFTER the user exists
RUN echo 'export ZSH_DISABLE_COMPFIX=true' > /home/node/.zshrc && \
  echo 'export PROMPT_COMMAND="history -a"' >> /home/node/.zshrc && \
  echo 'export HISTFILE=/commandhistory/.bash_history' >> /home/node/.zshrc && \
  echo 'export PATH=$PATH:/usr/local/share/npm-global/bin' >> /home/node/.zshrc && \
  echo 'export PATH="/home/node/.cargo/bin:$PATH"' >> /home/node/.zshrc && \
  chown node:node /home/node/.zshrc

ARG USERNAME=node

# Persist bash history.
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  && mkdir /commandhistory \
  && touch /commandhistory/.bash_history \
  && chown -R $USERNAME /commandhistory

# Set `DEVCONTAINER` environment variable to help with orientation
ENV DEVCONTAINER=true

# Create workspace and config directories and set permissions
RUN mkdir -p /workspace /home/node/.claude && \
  chown -R node:node /workspace /home/node/.claude

WORKDIR /workspace

RUN ARCH=$(dpkg --print-architecture) && \
  wget "https://github.com/dandavison/delta/releases/download/0.18.2/git-delta_0.18.2_${ARCH}.deb" && \
  dpkg -i "git-delta_0.18.2_${ARCH}.deb" && \
  rm "git-delta_0.18.2_${ARCH}.deb"

# Copy and set up firewall script
COPY init-firewall.sh /usr/local/bin/
COPY postCreateCommand.sh /usr/local/bin/

# deal with possible Windows line endings and ensure scripts are executable
RUN sed -i 's/\r$//' /usr/local/bin/init-firewall.sh && \
    chmod +x /usr/local/bin/init-firewall.sh
RUN sed -i 's/\r$//' /usr/local/bin/postCreateCommand.sh && \
    chmod +x /usr/local/bin/postCreateCommand.sh

RUN chmod +x /usr/local/bin/init-firewall.sh 
RUN chmod +x /usr/local/bin/postCreateCommand.sh

RUN chmod +x /usr/local/bin/init-firewall.sh && \
  echo "node ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/node-firewall && \
  chmod 0440 /etc/sudoers.d/node-firewall 
RUN echo "node ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/node-firewall
RUN echo 'node:dev123' | chpasswd

# NOW switch to non-root user
USER node

# Install global packages
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin

# Set the default shell to zsh rather than sh
ENV SHELL=/bin/zsh

# Simple zsh setup without problematic sourcing
RUN rm -f /home/node/.zshrc && \
    sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v1.2.0/zsh-in-docker.sh)" -- \
  -p git \
  -a 'export ZSH_DISABLE_COMPFIX=true' \
  -a 'export PROMPT_COMMAND="history -a"' \
  -a 'export HISTFILE=/commandhistory/.bash_history' \
  -x
# Install uv (Python package manager)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
  echo 'export PATH="/home/node/.cargo/bin:$PATH"' >> /home/node/.bashrc && \
  echo 'export PATH="/home/node/.cargo/bin:$PATH"' >> /home/node/.zshrc