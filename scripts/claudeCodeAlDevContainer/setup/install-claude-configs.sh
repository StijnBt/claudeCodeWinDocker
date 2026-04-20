#!/bin/bash
set -e

if [ -d "$HOME/claude-configs/.git" ]; then
    echo "claude-configs already cloned, pulling latest..."
    git -C "$HOME/claude-configs" pull
else
    git clone https://github.com/StefanMaron/claude-configs.git "$HOME/claude-configs"
fi

# Ensure the marketplace catalog exists so Claude Code can discover plugins
MARKETPLACE_DIR="$HOME/claude-configs/.claude-plugin"
MARKETPLACE_JSON="$MARKETPLACE_DIR/marketplace.json"
if [ ! -f "$MARKETPLACE_JSON" ]; then
    mkdir -p "$MARKETPLACE_DIR"
    cat > "$MARKETPLACE_JSON" <<'EOF'
{
  "name": "local",
  "plugins": [
    {
      "name": "profile-al-development",
      "source": "./plugins/profile-al-development",
      "description": "AL development profile for Business Central"
    }
  ]
}
EOF
    echo "Created $MARKETPLACE_JSON"
fi

# Ensure the profile-al-development plugin exists
PLUGIN_DIR="$HOME/claude-configs/plugins/profile-al-development"
PLUGIN_JSON="$PLUGIN_DIR/.claude-plugin/plugin.json"
if [ ! -f "$PLUGIN_JSON" ]; then
    mkdir -p "$PLUGIN_DIR/.claude-plugin"
    cat > "$PLUGIN_JSON" <<'EOF'
{
  "name": "profile-al-development",
  "version": "1.0.0",
  "description": "AL development profile for Business Central"
}
EOF
    echo "Created $PLUGIN_JSON"
fi

mkdir -p "$HOME/claude-al-development"

SETTINGS="$HOME/claude-al-development/settings.json"
if [ ! -f "$SETTINGS" ]; then
    echo "eyJleHRyYUtub3duTWFya2V0cGxhY2VzIjp7ImxvY2FsIjp7InNvdXJjZSI6eyJzb3VyY2UiOiJkaXJlY3RvcnkiLCJwYXRoIjoiL2hvbWUvdnNjb2RlL2NsYXVkZS1jb25maWdzIn19fSwiZW5hYmxlZFBsdWdpbnMiOnsicHJvZmlsZS1hbC1kZXZlbG9wbWVudEBsb2NhbCI6dHJ1ZX19" | base64 -d > "$SETTINGS"
    echo "Created $SETTINGS"
else
    echo "settings.json already exists at $SETTINGS - skipping"
fi
