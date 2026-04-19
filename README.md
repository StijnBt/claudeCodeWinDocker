# claudeCodeWinDocker

Runs [Claude Code](https://claude.ai/code) inside a hardened Docker container on Windows (WSL2), with strict network restrictions to prevent the AI agent from reaching unauthorized services.

---

## Credits

This project is a fork of [StefanMaron/claudeCodeAlDevContainer](https://github.com/StefanMaron/claudeCodeAlDevContainer) by [Stefan Maron](https://github.com/StefanMaron). The core sandbox architecture, security hardening, and firewall design all originate from his work. Many thanks to Stefan for laying the foundation that made this project possible.

---

## Prerequisites

- Windows 10 (build 19041+) or Windows 11
- WSL
- An [Anthropic API key](https://console.anthropic.com/)
- [Windows Terminal](https://aka.ms/terminal) — required for the VS Code task. Pre-installed on Windows 11; on Windows 10 it must be installed separately from the Microsoft Store or via `winget install Microsoft.WindowsTerminal`. Another terminal can be configured or the internal one from VS Code could be used.

---

## Installation

Open PowerShell **as Administrator** and run:

```powershell
.\scripts\claudeCodeAlDevContainer\install\install.ps1
```

This will:

1. Enable the WSL2 Windows features *(a reboot is required if not already enabled — rerun the script after rebooting)*
2. Install an Ubuntu distribution in WSL2
3. Install Docker Engine inside Ubuntu
4. Optionally install Claude Code on Windows itself

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

Open the repo in VS Code and run the **Claude Code Sandbox** task:
`Ctrl+Shift+P` → **Tasks: Run Task** → **Claude Code Sandbox**

This opens a new Windows Terminal tab, launches WSL2, and starts the container.

### Via terminal

In a WSL2 terminal at the repo root:

```bash
bash scripts/claudeCodeAlDevContainer/run-sandbox.sh
```

The Docker image (`claude-code-sandbox`) is built automatically on first run.

---

## What the sandbox does

When the container starts (before Claude Code launches):

- Firewall egress rules are applied — all outbound traffic is blocked except for:
  - `api.anthropic.com`
  - `claude.ai`
  - `console.anthropic.com`
  - `statsig.anthropic.com`
  - `marketplace.visualstudio.com`
  - `vscode.blob.core.windows.net`
  - `update.code.visualstudio.com`
- IPv6 is disabled to prevent firewall bypass
- VS Code IPC sockets are removed to block host command execution via the remote extension protocol
- Sudo access is locked down to only allow running the firewall script
- The firewall and hardening scripts are made immutable (`chattr +i`)

## Mounts

| Host | Container | Notes |
|---|---|---|
| Current directory | `/workspaces/project` | Your project files |
| `~/claude-al-development` | `/home/vscode/.claude` | Claude config, persisted across runs |
| `~/.config/git/config` | `/home/vscode/.gitconfig` | Git identity, read-only |

---

## Rebuilding the image

After modifying any file under `scripts/claudeCodeAlDevContainer/src/`:

```bash
docker build -t claude-code-sandbox scripts/claudeCodeAlDevContainer/src
```

Or remove the image and let `run-sandbox.sh` rebuild it on next launch:

```bash
docker rmi claude-code-sandbox
```

---

## Uninstall

Run as Administrator:

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
