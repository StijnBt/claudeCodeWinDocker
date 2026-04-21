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

    if [ -d "$CONFIGS_DIR/.git" ]; then
        echo "Updating claude-configs..."
        gosu vscode git -C "$CONFIGS_DIR" pull || echo "git pull failed, continuing with existing clone"
    else
        echo "Cloning claude-configs..."
        gosu vscode git clone https://github.com/StefanMaron/claude-configs.git "$CONFIGS_DIR"
    fi

    PLUGIN_SRC="$CONFIGS_DIR/profile-al-development"

    for subdir in agents skills commands; do
        mkdir -p "$CLAUDE_DIR/$subdir"
        chown vscode:vscode "$CLAUDE_DIR/$subdir"
        [ -d "$PLUGIN_SRC/$subdir" ] || continue
        for f in "$PLUGIN_SRC/$subdir"/*; do
            [ -e "$f" ] || continue
            fname=$(basename "$f")
            ln -sf "$PLUGIN_SRC/$subdir/$fname" "$CLAUDE_DIR/$subdir/$fname"
            chown -h vscode:vscode "$CLAUDE_DIR/$subdir/$fname"
        done
    done

    CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
    if [ ! -e "$CLAUDE_MD" ] || [ -L "$CLAUDE_MD" ]; then
        ln -sf "$PLUGIN_SRC/CLAUDE.md" "$CLAUDE_MD"
        chown -h vscode:vscode "$CLAUDE_MD"
    fi

    cat > "$CLAUDE_DIR/settings.json" <<EOF
{
  "enabledPlugins": {
    "$PLUGIN_SRC": true
  },
  "skipDangerousModePermissionPrompt": true
}
EOF
else
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
