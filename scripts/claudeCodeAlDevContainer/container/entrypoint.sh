#!/bin/bash
set -e

# Run as root: initialize firewall and harden the environment
/usr/local/bin/init-firewall.sh

# Persist ~/.claude.json in the host config folder. Claude Code writes onboarding
# state and user config to ~/.claude.json, which lives outside ~/.claude/. We
# symlink it into the mounted folder so it survives container removal.
CLAUDE_JSON="/home/vscode/.claude.json"
CLAUDE_JSON_HOST="/home/vscode/.claude/.claude.json"
if [ -f "$CLAUDE_JSON_HOST" ] && [ ! -L "$CLAUDE_JSON" ]; then
    # Host folder has persisted data from a previous run — symlink to it
    rm -f "$CLAUDE_JSON"
    ln -s "$CLAUDE_JSON_HOST" "$CLAUDE_JSON"
    chown -h vscode:vscode "$CLAUDE_JSON"
elif [ -f "$CLAUDE_JSON" ] && [ ! -L "$CLAUDE_JSON" ]; then
    # First run: move the image-baked file into the host folder, then symlink
    mv "$CLAUDE_JSON" "$CLAUDE_JSON_HOST"
    ln -s "$CLAUDE_JSON_HOST" "$CLAUDE_JSON"
    chown vscode:vscode "$CLAUDE_JSON_HOST"
    chown -h vscode:vscode "$CLAUDE_JSON"
fi

# Profile-specific setup
CLAUDE_DIR="/home/vscode/.claude"

if [ "${CLAUDE_PROFILE}" = "al-development" ]; then
    CONFIGS_DIR="/home/vscode/claude-configs"

    cat > "$CLAUDE_DIR/settings.json" <<EOF
{
  "extraKnownMarketplaces": {
    "local": {
      "source": {
        "source": "directory",
        "path": "$CONFIGS_DIR"
      }
    }
  },
  "enabledPlugins": {
    "profile-al-development@local": true
  },
  "skipDangerousModePermissionPrompt": true
}
EOF
else
    # Remove any AL profile symlinks left from a previous run
    for subdir in agents skills commands; do
        if [ -d "$CLAUDE_DIR/$subdir" ]; then
            find "$CLAUDE_DIR/$subdir" -maxdepth 1 -type l -delete
        fi
    done
    [ -L "$CLAUDE_DIR/CLAUDE.md" ] && rm -f "$CLAUDE_DIR/CLAUDE.md"

    # Strip enabledPlugins from persisted .claude.json if jq is available
    CLAUDE_JSON_PERSIST="$CLAUDE_DIR/.claude.json"
    if [ -f "$CLAUDE_JSON_PERSIST" ] && command -v jq > /dev/null 2>&1; then
        tmp=$(mktemp)
        jq 'del(.enabledPlugins) | del(.marketplaces) | del(.extraKnownMarketplaces)' "$CLAUDE_JSON_PERSIST" > "$tmp" \
            && mv "$tmp" "$CLAUDE_JSON_PERSIST" \
            && chown vscode:vscode "$CLAUDE_JSON_PERSIST"
    fi

    cat > "$CLAUDE_DIR/settings.json" <<'EOF'
{
  "skipDangerousModePermissionPrompt": true
}
EOF
fi
chown vscode:vscode "$CLAUDE_DIR/settings.json"

# Fix workspace ownership (bind mount may be owned by host UID)
if [ -d /workspaces/project ]; then
    chown vscode:vscode /workspaces/project
fi

# Drop privileges and exec the user command
exec gosu vscode "$@"
