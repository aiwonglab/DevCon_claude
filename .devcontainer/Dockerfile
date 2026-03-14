FROM node:20
# FROM nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04

ARG TZ
ENV TZ="$TZ"

# ============================================================
# UNCOMMENT WHEN USING NVIDIA BASE: create node user first
# (node:20 already has this user; nvidia base does not)
# ============================================================
# RUN groupadd --gid 1000 node && \
#   useradd --uid 1000 --gid node --shell /bin/bash --create-home node

# Install development tools + Chromium/Playwright dependencies
RUN apt-get update && apt-get install -y \
    less \
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
    curl \
    libnss3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# UNCOMMENT WHEN USING NVIDIA BASE: install Node.js
# (node:20 already has Node + npm; nvidia base does not)
# ============================================================
# RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
#   apt-get install -y nodejs

# Install Claude Code (Node 20 already available from node:20 base)
RUN npm install -g @anthropic-ai/claude-code

# Fix zsh permissions and fzf issues
RUN chmod -R 755 /usr/local/share/zsh/ && \
  chown -R root:root /usr/local/share/zsh/ && \
  mkdir -p /usr/share/doc/fzf/examples && \
  find /usr/share/fzf -name "*.zsh" -exec cp {} /usr/share/doc/fzf/examples/ \; 2>/dev/null || true

# Add ZSH_DISABLE_COMPFIX to environment
ENV ZSH_DISABLE_COMPFIX=true

# Create minimal fzf files if they don't exist
RUN mkdir -p /usr/share/doc/fzf/examples && \
  echo '# FZF key bindings' > /usr/share/doc/fzf/examples/key-bindings.zsh && \
  echo '# FZF completion' > /usr/share/doc/fzf/examples/completion.zsh && \
  chmod 644 /usr/share/doc/fzf/examples/*.zsh

# Create directories and set permissions
# NOTE: node user must exist before this block — on nvidia base, uncomment user creation above first
RUN mkdir -p /usr/local/share/npm-global \
             /workspace \
             /home/node/.claude \
             /commandhistory && \
  touch /commandhistory/.bash_history && \
  chown -R node:node /usr/local/share \
                     /workspace \
                     /home/node/.claude \
                     /commandhistory

WORKDIR /workspace

# Install git-delta
RUN ARCH=$(dpkg --print-architecture) && \
  wget "https://github.com/dandavison/delta/releases/download/0.18.2/git-delta_0.18.2_${ARCH}.deb" && \
  dpkg -i "git-delta_0.18.2_${ARCH}.deb" && \
  rm "git-delta_0.18.2_${ARCH}.deb"

# Copy scripts, fix line endings, set permissions, configure sudoers — all in one layer
COPY init-firewall.sh /usr/local/bin/
COPY postCreateCommand.sh /usr/local/bin/
RUN sed -i 's/\r$//' /usr/local/bin/init-firewall.sh && \
    sed -i 's/\r$//' /usr/local/bin/postCreateCommand.sh && \
    chmod +x /usr/local/bin/init-firewall.sh \
             /usr/local/bin/postCreateCommand.sh && \
    echo "node ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/node-firewall && \
    echo "node ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/node-firewall && \
    chmod 0440 /etc/sudoers.d/node-firewall && \
    echo 'node:dev123' | chpasswd

# Persist bash history
ENV DEVCONTAINER=true

# Switch to non-root user
USER node

# Configure npm global path
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin
ENV SHELL=/bin/zsh

# Install oh-my-zsh and configure shell
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v1.2.0/zsh-in-docker.sh)" -- \
  -p git \
  -a 'export ZSH_DISABLE_COMPFIX=true' \
  -a 'export PROMPT_COMMAND="history -a"' \
  -a 'export HISTFILE=/commandhistory/.bash_history' \
  -a 'export PATH=$PATH:/usr/local/share/npm-global/bin' \
  -x

# Install uv (Python package manager; installs into ~/.cargo/bin)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
  echo 'export PATH="/home/node/.cargo/bin:$PATH"' >> /home/node/.bashrc && \
  echo 'export PATH="/home/node/.cargo/bin:$PATH"' >> /home/node/.zshrc

# Install Bun (required for gstack)
RUN curl -fsSL https://bun.sh/install | bash && \
  echo 'export PATH="/home/node/.bun/bin:$PATH"' >> /home/node/.bashrc && \
  echo 'export PATH="/home/node/.bun/bin:$PATH"' >> /home/node/.zshrc