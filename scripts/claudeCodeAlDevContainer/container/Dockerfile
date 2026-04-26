FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG VERSION=latest

# Install gosu for clean root→user privilege drop in entrypoint
RUN apt-get update \
    && apt-get install -y --no-install-recommends gosu \
    && rm -rf /var/lib/apt/lists/*

# Copy security scripts (co-located so install.sh's dirname trick works)

COPY install.sh /tmp/install.sh
COPY init-firewall.sh /tmp/init-firewall.sh
COPY harden-env.sh /tmp/harden-env.sh

# Fix CRLF line endings (Windows git checkout)
RUN sed -i 's/\r$//' /tmp/install.sh /tmp/init-firewall.sh /tmp/harden-env.sh

# Copy entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh \
    && chmod +x /usr/local/bin/entrypoint.sh

# Run install.sh with the devcontainer feature contract variables
ENV _REMOTE_USER=vscode
ENV _REMOTE_USER_HOME=/home/vscode
WORKDIR /tmp
RUN chmod +x /tmp/install.sh /tmp/init-firewall.sh /tmp/harden-env.sh \
    && VERSION="${VERSION}" bash install.sh

# Credential-stripping environment variables
ENV GIT_TERMINAL_PROMPT=0
ENV SSH_AUTH_SOCK=""
ENV GIT_ASKPASS=/bin/false
ENV VSCODE_GIT_ASKPASS_MAIN=""
ENV VSCODE_GIT_ASKPASS_NODE=""
ENV VSCODE_GIT_ASKPASS_EXTRA_ARGS=""
ENV GH_TOKEN=""
ENV GITHUB_TOKEN=""
ENV GIT_CONFIG_COUNT=1
ENV GIT_CONFIG_KEY_0=credential.helper
ENV GIT_CONFIG_VALUE_0=/bin/false
ENV BROWSER=""
ENV GPG_AGENT_INFO=""

# Enable LSP tool for code intelligence (go-to-definition, find-references, etc.)
ENV ENABLE_LSP_TOOL=1

# Ensure claude is on PATH for all shell types (profile.d only runs for login shells)
ENV PATH="/home/vscode/.local/bin:${PATH}"

WORKDIR /workspaces/project

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["claude", "--dangerously-skip-permissions"]
