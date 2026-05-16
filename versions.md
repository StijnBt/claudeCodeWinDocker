# Version history

## v1.20260516.0

Adds a third launch profile for Javier Armesto's ALDC-AL-Development-Collection plugin, introduces a VS Code workspace file with workspace-level tasks, and extends the firewall allowlist.

### New features

#### ALDC-AL-Development-Collection profile
`run-sandbox.sh` now offers a third option:
- **3) Claude Code with ALDC profile (Javier Armesto)** — registers Javier Armesto's [`ALDC-AL-Development-Collection`](https://github.com/javiarmesto/ALDC-AL-Development-Collection) plugin.

`install.sh` clones the repo into `/home/vscode/aldc-configs/` at image-build time. It then patches the repo's `.mcp.json` with `jq`: non-functional packages (`alcops`, `bc-telemetry-buddy`, `al-symbols-mcp`, `microsoft-docs`) are removed and Stefan Maron's working MCP entries are merged in, with `~` in paths expanded to the actual home directory.

`entrypoint.sh` handles the new `al-development-aldc` profile value:
- Symlinks agents, skills, commands, hooks, and `CLAUDE.md` from the plugin into `~/.claude/`.
- Writes `settings.json` pointing at the local `aldc-marketplace` directory and enabling `aldc@aldc-marketplace`.
- Seeds and patches `.claude.json` via `jq` so Claude Code treats the plugin as installed on first launch.

#### VS Code workspace file
`claudeCodeWinDocker.code-workspace` added at repo root. Contains the `app` and `test` folder entries plus all four VS Code tasks (Run, Install, Uninstall, Clear Docker Image), keeping workspace-level and folder-level task definitions in sync.

#### Firewall: `mcp.context7.com` allowlisted
`init-firewall.sh` now resolves and allows `mcp.context7.com` alongside the existing approved domains.

#### Hooks cleanup on vanilla reset
The vanilla-mode cleanup loop in `entrypoint.sh` now also removes leftover symlinks from the `hooks/` subdirectory (previously only `agents`, `skills`, and `commands` were cleaned).

### Other changes
- `README.md` updated: profile list reflects all three options; workspace/app/symbolic-link usage note added; CI/CD section removed.

## v1.20260426.0

A profile-aware, self-contained variant of the sandbox. The main goal of this branch is to let a single Docker image serve both vanilla Claude Code and the AL Development experience without requiring any host-side plugin setup.

### New features

#### Profile selection at launch
`run-sandbox.sh` now presents a menu:
- **1) Vanilla Claude Code** — clean Claude Code, no plugins, no agents, no commands
- **2) Claude Code with AL Development profile (Stefan Maron)** — full AL/BC development setup

The chosen profile is passed to the container as `CLAUDE_PROFILE`, and `entrypoint.sh` configures `~/.claude/` accordingly on every start.

#### AL plugin baked into the image
`install.sh` clones [StefanMaron/claude-configs](https://github.com/StefanMaron/claude-configs) into `/home/vscode/claude-configs/` during the Docker build. There is no longer a separate host-side `install-claude-configs.sh` step — the plugin travels with the image.

#### Auto-generated plugin manifests
If Stefan Maron's repo does not include `.claude-plugin/marketplace.json` or `.claude-plugin/plugin.json`, `install.sh` writes fallback manifests so Claude Code's plugin resolver can discover the plugin. When the upstream repo ships its own manifests, those are kept untouched.

#### Marketplace registration via user settings
For the AL profile, `entrypoint.sh` writes a `~/.claude/settings.json` containing:
```json
{
  "extraKnownMarketplaces": {
    "claude-configs": {
      "source": { "source": "directory", "path": "/home/vscode/claude-configs" }
    }
  },
  "enabledPlugins": {
    "profile-al-development@claude-configs": true
  }
}
```
Claude Code's native plugin system handles the rest — the plugin shows up in `/plugin` and its agents in `/agents`.

#### Direct symlink fallback
On top of the marketplace registration, `entrypoint.sh` also symlinks each agent / skill / command file from the plugin directly into `~/.claude/agents/`, `~/.claude/skills/`, and `~/.claude/commands/`, plus the plugin's `CLAUDE.md` as the user-level `CLAUDE.md`. This keeps the AL content discoverable even if Claude Code's plugin resolver hits an issue.

#### Profile-aware cleanup
When a session is started in vanilla mode after an AL session, `entrypoint.sh`:
- Removes any AL plugin symlinks left in `~/.claude/agents/`, `~/.claude/skills/`, `~/.claude/commands/`, and `~/.claude/CLAUDE.md`
- Wipes `~/.claude/plugins/` so the AL plugin's installed/known-marketplace state does not bleed through
- Strips `enabledPlugins`, `marketplaces`, and `extraKnownMarketplaces` from the persisted `~/.claude/.claude.json` (using `jq`)
- Writes a minimal `settings.json`

The result: vanilla mode looks completely clean even if you ran AL mode in the previous session.

#### `clear-image.sh` and matching VS Code task
A new helper script removes the local `claude-code-sandbox` image so the next `run-sandbox.sh` triggers a fresh build. The VS Code task **claudeCodeWinDocker: Clear Docker Image** wraps it.

#### Confirmation prompt on uninstall
`uninstall.ps1` now requires explicit `Y` confirmation before doing anything. The previous version started removing Claude Code and unregistering Ubuntu immediately on launch.

#### Repository layout cleanup
- `scripts/claudeCodeAlDevContainer/src/` → `scripts/claudeCodeAlDevContainer/container/`
- `scripts/claudeCodeAlDevContainer/install/` → `scripts/claudeCodeAlDevContainer/setup/`
- `jq` added to the runtime image (used by the vanilla cleanup logic)
- `.gitattributes` added to enforce LF line endings on shell scripts
