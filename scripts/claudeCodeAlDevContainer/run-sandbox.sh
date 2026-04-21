#!/bin/bash
# Fix CRLF in this script itself
sed -i 's/\r$//' "$0"
# Determine repo root first (script is in scripts/claudeCodeAlDevContainer/)
SCRIPT_DIR=$(dirname "$(realpath "$0")")
REPO_ROOT=$(dirname "$(dirname "$SCRIPT_DIR")")

# Auto-fix CRLF line endings
if ! command -v dos2unix > /dev/null 2>&1; then
    sudo apt-get install -y dos2unix -qq
fi
find "$REPO_ROOT" -name "*.sh" | xargs dos2unix -q 2>/dev/null || true

# Fix ~/.config/git/config if Docker accidentally created it as a directory
GITCONFIG_HOST="$HOME/.config/git/config"
if [ -d "$GITCONFIG_HOST" ]; then
    echo "Removing Docker artefact directory at $GITCONFIG_HOST (requires sudo)..."
    sudo rm -rf "$GITCONFIG_HOST"
fi

# Ensure claude-configs is cloned and symlinks are in place
"$SCRIPT_DIR/setup/install-claude-configs.sh"

# Auto-build image if not present
if ! docker image inspect claude-code-sandbox > /dev/null 2>&1; then
    echo "Image 'claude-code-sandbox' not found, building..."
    docker build -t claude-code-sandbox "$REPO_ROOT/scripts/claudeCodeAlDevContainer/container"
fi

GITCONFIG_MOUNT=()
if [ -f "$GITCONFIG_HOST" ]; then
    GITCONFIG_MOUNT=(-v "$GITCONFIG_HOST:/home/vscode/.gitconfig:ro")
fi

docker run -it --rm \
  --cap-add=NET_ADMIN --cap-add=NET_RAW \
  -e ANTHROPIC_API_KEY \
  -v "$HOME/claude-al-development:/home/vscode/.claude" \
  -v "$HOME/claude-configs:/home/vscode/claude-configs:ro" \
  "${GITCONFIG_MOUNT[@]}" \
  -v "$(pwd):/workspaces/project" \
  claude-code-sandbox

