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

# Auto-build image if not present
if ! docker image inspect claude-code-sandbox > /dev/null 2>&1; then
    echo "Image 'claude-code-sandbox' not found, building..."
    docker build -t claude-code-sandbox "$REPO_ROOT/scripts/claudeCodeAlDevContainer/src"
fi

docker run -it --rm \
  --cap-add=NET_ADMIN --cap-add=NET_RAW \
  -e ANTHROPIC_API_KEY \
  -v "$HOME/claude-al-development:/home/vscode/.claude" \
  -v "$HOME/claude-configs:/home/vscode/claude-configs:ro" \
  -v "$HOME/.config/git/config:/home/vscode/.gitconfig:ro" \
  -v "$(pwd):/workspaces/project" \
  claude-code-sandbox

