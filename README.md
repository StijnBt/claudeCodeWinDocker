# claudeCodeWinDocker

Runs [Claude Code](https://claude.ai/code) inside a hardened Docker container on Windows (WSL2).
A strict egress firewall prevents the AI agent from reaching unauthorized services.

Two profiles are available at launch:
1) **Vanilla Claude Code**
2) **Profile AL Development** (preconfigured with Stefan Maron's [`profile-al-development`](https://github.com/StefanMaron/claude-configs) plugin).

---

## Credits

This project is a fork of [StefanMaron/claudeCodeAlDevContainer](https://github.com/StefanMaron/claudeCodeAlDevContainer) by [Stefan Maron](https://github.com/StefanMaron). The core sandbox architecture, security hardening, firewall design, and AL development plugin all originate from his work. Many thanks to Stefan for laying the foundation that made this project possible.

---

## Prerequisites

- Windows 10 (build 19041+) or Windows 11
- WSL2
- A Claude account type that supports Claude Code
- [Windows Terminal](https://aka.ms/terminal)

---

## Installation

> **Note:** VS Code must be started **Run as Administrator** for tasks to work correctly.

Run the VS Code task **claudeCodeWinDocker: Install** (requires VS Code started as Administrator), or open PowerShell **as Administrator** and run:

```powershell
.\scripts\claudeCodeAlDevContainer\setup\install.ps1
```

This will:

1. Enable the WSL2 Windows features
2. Install an Ubuntu distribution in WSL2
3. Configure Git user settings in WSL2
4. Install Docker Engine inside Ubuntu
5. Optionally install Claude Code on Windows itself

---

## Running the sandbox

### Via VS Code

> **Note:** VS Code must be started **Run as Administrator** for tasks to work correctly.

`Ctrl+Shift+P` → **Tasks: Run Task** → **claudeCodeWinDocker: Run**.

This opens a new Windows Terminal tab, launches WSL2, and starts the container.

The Docker image (`claude-code-sandbox`) is built automatically on first run.

### Profile selection

On launch you choose:

```
1) Vanilla Claude Code
2) Profile AL Development
```

- **Vanilla** — clean Claude Code with no plugins, agents, or commands. Any AL plugin state from a previous session is wiped before start.
- **AL Development** — registers the local marketplace `claude-configs`, enables `profile-al-development@claude-configs`, and symlinks the plugin's agents, skills, commands, and `CLAUDE.md` into `~/.claude/`.

---

## Mounts

| Host (WSL2) | Container | Notes |
|---|---|---|
| Current directory | `/workspaces/project` | Your project files |
| `claude-code-data` (Docker volume) | `/home/vscode/.claude` | Claude config, plugin state, and onboarding flags, persisted across runs |
| `~/.config/git/config` (if exists) | `/home/vscode/.gitconfig` | Git identity, read-only |

The `claude-configs` plugin sources are baked into the image at `/home/vscode/claude-configs/` and not mounted from the host.

---

## Rebuilding the image

> **Note:** VS Code must be started **Run as Administrator** for tasks to work correctly.

After modifying any file under `scripts/claudeCodeAlDevContainer/container/`, rebuild via VS Code task **claudeCodeWinDocker: Clear Docker Image** (which removes the image so the next run rebuilds it), or manually:


---

## CI / CD

GitHub Actions workflows run on every push:

- **Lint** — shellcheck (bash), hadolint (Dockerfile), PSScriptAnalyzer (PowerShell)
- **Build & smoke test** — builds the Docker image and verifies the container starts and the firewall initialises correctly

On `v*` tag push, the release workflow builds and publishes the image to GHCR and creates a GitHub Release with auto-generated notes.

---

## Uninstall

> **Note:** VS Code must be started **Run as Administrator** for tasks to work correctly.

Run the VS Code task **claudeCodeWinDocker: Uninstall** (requires VS Code started as Administrator), or run as Administrator:


A confirmation prompt is shown before any destructive action. Removes Claude Code, Ubuntu from WSL2, and disables the WSL2 Windows features. A reboot is required.

---

## Why Docker on WSL2 instead of Docker Desktop?

Docker Engine can run on Windows, but in that configuration it only supports Windows containers. This sandbox is built on Ubuntu and requires Linux containers, so Docker Engine on Windows alone is not an option. WSL2 provides the Linux environment needed to run Docker Engine with Linux container support on a Windows machine.

Beyond that, the sandbox relies on Linux kernel features that Docker Desktop does not expose reliably:

- **iptables / ipset / ip6tables** — used to enforce egress firewall rules inside the container. These require direct access to the Linux kernel networking stack.
- **NET_ADMIN / NET_RAW capabilities** — needed so the container can configure its own firewall on startup. These work correctly when Docker runs natively inside WSL2.
- **chattr +i** — makes the firewall and hardening scripts immutable so the agent cannot tamper with them. Requires an ext4 filesystem, which WSL2's virtual disk provides.
- **No licensing cost** — Docker Engine inside WSL2 is free with no commercial license requirements.

Docker Desktop abstracts the Linux kernel behind its own VM in a way that breaks these mechanisms. Running Docker directly inside WSL2 (Ubuntu) gives the container a real Linux kernel and makes the security guarantees reliable.
