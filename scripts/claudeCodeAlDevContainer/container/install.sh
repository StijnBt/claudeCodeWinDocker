#!/bin/bash
set -e

CLAUDE_CODE_VERSION="${VERSION:-latest}"

echo "Installing Claude Code ${CLAUDE_CODE_VERSION} for user ${_REMOTE_USER}..."

# Ensure curl is available
if ! command -v curl &> /dev/null; then
    apt-get update
    apt-get install -y --no-install-recommends curl ca-certificates
    rm -rf /var/lib/apt/lists/*
fi

# Install networking tools for the firewall, and Node.js for AL MCP servers
apt-get update
apt-get install -y --no-install-recommends iptables ipset iproute2 dnsutils e2fsprogs nodejs npm jq
rm -rf /var/lib/apt/lists/*

# Install AL development MCP servers globally (must happen before firewall is active)
npm install -g al-mcp-server bc-code-intelligence-mcp

# Install Claude Code for the remote user
if [ "${_REMOTE_USER}" = "root" ]; then
    if [ "${CLAUDE_CODE_VERSION}" = "latest" ]; then
        curl -fsSL https://claude.ai/install.sh | bash
    else
        curl -fsSL https://claude.ai/install.sh | bash -s "${CLAUDE_CODE_VERSION}"
    fi
else
    if [ "${CLAUDE_CODE_VERSION}" = "latest" ]; then
        su - "${_REMOTE_USER}" -c "curl -fsSL https://claude.ai/install.sh | bash"
    else
        su - "${_REMOTE_USER}" -c "curl -fsSL https://claude.ai/install.sh | bash -s '${CLAUDE_CODE_VERSION}'"
    fi
fi

# Add to PATH for all users and non-interactive shells
echo "export PATH=\"${_REMOTE_USER_HOME}/.local/bin:\$PATH\"" > /etc/profile.d/claude-code.sh
chmod +x /etc/profile.d/claude-code.sh

# Pre-seed ~/.claude.json to skip onboarding wizard
CLAUDE_JSON="${_REMOTE_USER_HOME}/.claude.json"
if [ ! -f "${CLAUDE_JSON}" ]; then
    echo '{"hasCompletedOnboarding":true,"numStartups":1,"installMethod":"native"}' > "${CLAUDE_JSON}"
    chown "${_REMOTE_USER}:${_REMOTE_USER}" "${CLAUDE_JSON}"
fi

# Clone AL development configs (must happen before firewall is active)
su - "${_REMOTE_USER}" -c "git clone https://github.com/StefanMaron/claude-configs.git ${_REMOTE_USER_HOME}/claude-configs"

# Create marketplace manifest if the repo doesn't include one (required by Claude Code to resolve plugins)
CONFIGS_DIR="${_REMOTE_USER_HOME}/claude-configs"
MARKETPLACE_DIR="${CONFIGS_DIR}/.claude-plugin"
if [ ! -f "${MARKETPLACE_DIR}/marketplace.json" ]; then
    mkdir -p "${MARKETPLACE_DIR}"
    cat > "${MARKETPLACE_DIR}/marketplace.json" <<'EOF'
{
  "name": "al-development-configs",
  "owner": { "name": "StefanMaron" },
  "plugins": [
    {
      "name": "profile-al-development",
      "source": "./profile-al-development",
      "strict": false
    }
  ]
}
EOF
    chown -R "${_REMOTE_USER}:${_REMOTE_USER}" "${MARKETPLACE_DIR}"
fi

# Create plugin manifest if the plugin directory doesn't include one
PLUGIN_DIR="${CONFIGS_DIR}/profile-al-development/.claude-plugin"
if [ ! -f "${PLUGIN_DIR}/plugin.json" ]; then
    mkdir -p "${PLUGIN_DIR}"
    cat > "${PLUGIN_DIR}/plugin.json" <<'EOF'
{
  "name": "profile-al-development",
  "description": "AL Development Profile by StefanMaron",
  "version": "1.0.0"
}
EOF
    chown -R "${_REMOTE_USER}:${_REMOTE_USER}" "${PLUGIN_DIR}"
fi

# Install firewall script and make it owned by root
cp "$(dirname "$0")/init-firewall.sh" /usr/local/bin/init-firewall.sh
chmod 755 /usr/local/bin/init-firewall.sh
chown root:root /usr/local/bin/init-firewall.sh

# Install environment hardening script (strips VS Code IPC escape vectors)
cp "$(dirname "$0")/harden-env.sh" /usr/local/bin/harden-env.sh
chmod 755 /usr/local/bin/harden-env.sh
chown root:root /usr/local/bin/harden-env.sh

# Inject harden-env.sh as the first line of .bashrc so it runs for ALL bash sessions.
# Must be BEFORE the interactive guard ([ -z "$PS1" ] && return) to catch non-interactive shells too.
BASHRC="${_REMOTE_USER_HOME}/.bashrc"
if [ -f "$BASHRC" ]; then
    if ! grep -q 'harden-env.sh' "$BASHRC"; then
        sed -i '1i source /usr/local/bin/harden-env.sh' "$BASHRC"
    fi
else
    echo 'source /usr/local/bin/harden-env.sh' > "$BASHRC"
    chown "${_REMOTE_USER}:${_REMOTE_USER}" "$BASHRC"
fi

# Grant the container user passwordless sudo ONLY for the firewall script
echo "${_REMOTE_USER} ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/${_REMOTE_USER}-firewall
chmod 0440 /etc/sudoers.d/${_REMOTE_USER}-firewall

# Remove SUID/SGID bits from non-essential binaries to limit privilege escalation
find /usr -type f \( -perm -4000 -o -perm -2000 \) \
    ! -name "sudo" \
    ! -name "init-firewall.sh" \
    -exec chmod u-s,g-s {} \; 2>/dev/null || true

echo "Claude Code installed successfully."
