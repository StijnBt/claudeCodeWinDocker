#!/bin/bash
set -e

if [ -d "$HOME/claude-configs/.git" ]; then
    echo "claude-configs already cloned, pulling latest..."
    git -C "$HOME/claude-configs" pull
else
    git clone https://github.com/StefanMaron/claude-configs.git "$HOME/claude-configs"
fi

mkdir -p "$HOME/claude-al-development"

SETTINGS="$HOME/claude-al-development/settings.json"
if [ ! -f "$SETTINGS" ]; then
    echo "eyJleHRyYUtub3duTWFya2V0cGxhY2VzIjp7ImxvY2FsIjp7InNvdXJjZSI6eyJzb3VyY2UiOiJkaXJlY3RvcnkiLCJwYXRoIjoiL2hvbWUvdnNjb2RlL2NsYXVkZS1jb25maWdzIn19fSwiZW5hYmxlZFBsdWdpbnMiOnsicHJvZmlsZS1hbC1kZXZlbG9wbWVudEBsb2NhbCI6dHJ1ZX19" | base64 -d > "$SETTINGS"
    echo "Created $SETTINGS"
else
    echo "settings.json already exists at $SETTINGS - skipping"
fi
