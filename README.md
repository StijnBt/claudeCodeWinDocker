# claudeCodeWinDocker

Runs [Claude Code](https://claude.ai/code) inside a hardened Docker container on Windows (WSL2), preconfigured for AL / Business Central development. Strict network restrictions prevent the AI agent from reaching unauthorized services.

---

## Credits

This project is a fork of [StefanMaron/claudeCodeAlDevContainer](https://github.com/StefanMaron/claudeCodeAlDevContainer) by [Stefan Maron](https://github.com/StefanMaron). The core sandbox architecture, security hardening, firewall design, and AL development plugin all originate from his work. Many thanks to Stefan for laying the foundation that made this project possible.

---

## Prerequisites

- Windows 10 (build 19041+) or Windows 11
- WSL2
- An [Anthropic API key](https://console.anthropic.com/)
- [Windows Terminal](https://aka.ms/terminal) — required for the VS Code tasks. Pre-installed on Windows 11; install separately on Windows 10 via the Microsoft Store or `winget install Microsoft.WindowsTerminal`.

---

## Installation

Run the VS Code task **claudeCodeWinDocker: Install** (requires VS Code started as Administrator), or open PowerShell **as Administrator** and run:

```powershell
.\scripts\claudeCodeAlDevContainer\install\install.ps1
```

This will:

1. Enable the WSL2 Windows features *(a reboot is required if not already enabled — rerun the script after rebooting)*
2. Install an Ubuntu distribution in WSL2
3. Configure Git user settings in WSL2
4. Install Docker Engine inside Ubuntu
5. Optionally install Claude Code on Windows itself
6. Clone [StefanMaron/claude-configs](https://github.com/StefanMaron/claude-configs) and configure the AL development plugin

**Flags:**

| Flag | Effect |
|---|---|
| `-SkipDocker` | Skip Docker installation (use if Docker is already set up in WSL2) |
| `-SkipClaude` | Skip the Claude Code for Windows prompt |

---

## Configuration

Set your Anthropic API key in your WSL2 terminal:

```bash
echo 'export ANTHROPIC_API_KEY=sk-ant-...' >> ~/.bashrc
source ~/.bashrc
```

---

## Running the sandbox

### Via VS Code

> **Note:** VS Code must be started **Run as Administrator** for tasks to work correctly.

Open the repo in VS Code and run the task via `Ctrl+Shift+P` → **Tasks: Run Task** → **claudeCodeWinDocker: Run**.

This opens a new Windows Terminal tab, launches WSL2, and starts the container.

### Via terminal

In a WSL2 terminal at the repo root:

```bash
bash scripts/claudeCodeAlDevContainer/run-sandbox.sh
```

The Docker image (`claude-code-sandbox`) is built automatically on first run.

### Pre-built image

A pre-built image is published to the GitHub Container Registry on every release:

```bash
docker pull ghcr.io/stijnbt/claude-code-sandbox:latest
```

---

## AL development plugin

The sandbox includes the [profile-al-development](https://github.com/StefanMaron/claude-configs/tree/master/profile-al-development) plugin from `claude-configs`, which adds:

- **Slash commands**: `/interview`, `/plan`, `/develop`, `/fix`, `/test`, `/document`
- **MCP servers** (pre-installed in the image):
  - `al-mcp-server` — AL build, compile, publish, symbol search, and diagnostics via `altool`
  - `bc-code-intelligence-mcp` — Business Central code intelligence
  - `microsoft_docs_mcp` — Microsoft Learn documentation at `learn.microsoft.com/api/mcp`

The plugin profile is mounted from `~/claude-configs` in WSL2 and persisted across container restarts.

---

## What the sandbox does

When the container starts (before Claude Code launches):

- Firewall egress rules are applied — all outbound traffic is blocked except:
  - `api.anthropic.com`
  - `claude.ai`
  - `console.anthropic.com`
  - `statsig.anthropic.com`
  - `marketplace.visualstudio.com`
  - `vscode.blob.core.windows.net`
  - `update.code.visualstudio.com`
  - `learn.microsoft.com`
- IPv6 is disabled to prevent firewall bypass
- VS Code IPC sockets are removed to block host command execution via the remote extension protocol
- Sudo access is locked down to only allow running the firewall script
- The firewall and hardening scripts are made immutable (`chattr +i`)

---

## Mounts

| Host (WSL2) | Container | Notes |
|---|---|---|
| Current directory | `/workspaces/project` | Your project files |
| `~/claude-al-development` | `/home/vscode/.claude` | Claude config and settings, persisted across runs |
| `~/claude-configs` | `/home/vscode/claude-configs` | AL development plugin, read-only |
| `~/.config/git/config` | `/home/vscode/.gitconfig` | Git identity, read-only |

---

## Rebuilding the image

After modifying any file under `scripts/claudeCodeAlDevContainer/container/`, rebuild via VS Code task **claudeCodeWinDocker: (Re)Build Docker Image**, or manually:

```bash
docker build -t claude-code-sandbox scripts/claudeCodeAlDevContainer/container
```

Or remove the image and let `run-sandbox.sh` rebuild it on next launch:

```bash
docker rmi claude-code-sandbox
```

---

## CI / CD

GitHub Actions workflows run on every push:

- **Lint** — shellcheck (bash), hadolint (Dockerfile), PSScriptAnalyzer (PowerShell)
- **Build & smoke test** — builds the Docker image and verifies the container starts and the firewall initialises correctly

On `v*` tag push, the release workflow builds and publishes the image to GHCR and creates a GitHub Release with auto-generated notes.

---

## Uninstall

Run the VS Code task **claudeCodeWinDocker: Uninstall** (requires VS Code started as Administrator), or run as Administrator:

```powershell
.\scripts\claudeCodeAlDevContainer\install\uninstall.ps1
```

Removes Claude Code, Ubuntu from WSL2, and disables the WSL2 Windows features. A reboot is required.

---

## Why Docker on WSL2 instead of Docker Desktop?

Docker Engine can run on Windows, but in that configuration it only supports Windows containers. This sandbox is built on Ubuntu and requires Linux containers, so Docker Engine on Windows alone is not an option. WSL2 provides the Linux environment needed to run Docker Engine with Linux container support on a Windows machine.

Beyond that, the sandbox relies on Linux kernel features that Docker Desktop does not expose reliably:

- **iptables / ipset / ip6tables** — used to enforce egress firewall rules inside the container. These require direct access to the Linux kernel networking stack.
- **NET_ADMIN / NET_RAW capabilities** — needed so the container can configure its own firewall on startup. These work correctly when Docker runs natively inside WSL2.
- **chattr +i** — makes the firewall and hardening scripts immutable so the agent cannot tamper with them. Requires an ext4 filesystem, which WSL2's virtual disk provides.
- **No licensing cost** — Docker Engine inside WSL2 is free with no commercial license requirements.

Docker Desktop abstracts the Linux kernel behind its own VM in a way that breaks these mechanisms. Running Docker directly inside WSL2 (Ubuntu) gives the container a real Linux kernel and makes the security guarantees reliable.
