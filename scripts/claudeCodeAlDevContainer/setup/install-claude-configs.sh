#!/bin/bash
set -e

if [ -d "$HOME/claude-configs/.git" ]; then
    echo "claude-configs already cloned, pulling latest..."
    git -C "$HOME/claude-configs" pull
else
    git clone https://github.com/StefanMaron/claude-configs.git "$HOME/claude-configs"
fi

mkdir -p "$HOME/claude-al-development"

# Expose plugin content directly in user config via container-valid symlinks.
# run-sandbox.sh mounts:
#   $HOME/claude-al-development  →  /home/vscode/.claude          (user config)
#   $HOME/claude-configs         →  /home/vscode/claude-configs   (read-only)
# Symlinks point to /home/vscode/claude-configs/... which is valid inside the
# container even though the path doesn't exist on the WSL host.
PLUGIN_SRC_CONTAINER="/home/vscode/claude-configs/profile-al-development"
PLUGIN_SRC_HOST="$HOME/claude-configs/profile-al-development"

link_plugin_dir() {
    local subdir="$1"
    local src="$PLUGIN_SRC_HOST/$subdir"
    local dst="$HOME/claude-al-development/$subdir"
    mkdir -p "$dst"
    [ -d "$src" ] || return 0
    for f in "$src"/*; do
        [ -e "$f" ] || continue
        fname=$(basename "$f")
        ln -sf "$PLUGIN_SRC_CONTAINER/$subdir/$fname" "$dst/$fname"
    done
    echo "Linked $subdir from plugin"
}

link_plugin_dir agents
link_plugin_dir skills
link_plugin_dir commands

# Link user-scope CLAUDE.md (replace if it's already a symlink, skip if real file)
CLAUDE_MD="$HOME/claude-al-development/CLAUDE.md"
if [ ! -e "$CLAUDE_MD" ] || [ -L "$CLAUDE_MD" ]; then
    ln -sf "$PLUGIN_SRC_CONTAINER/CLAUDE.md" "$CLAUDE_MD"
    echo "Linked CLAUDE.md from plugin"
fi

SETTINGS="$HOME/claude-al-development/settings.json"
if [ ! -f "$SETTINGS" ]; then
    echo '{}' > "$SETTINGS"
    echo "Created $SETTINGS"
fi
