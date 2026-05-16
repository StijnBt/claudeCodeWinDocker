# claudeCodeWinDocker

Runs [Claude Code](https://claude.ai/code) inside a hardened Docker container on Windows (WSL2).
A strict egress firewall prevents the AI agent from reaching unauthorized services.

Two profiles are available at launch:
1) **Vanilla Claude Code**
2) **Profile AL Development** (preconfigured with Stefan Maron's [`profile-al-development`](https://github.com/StefanMaron/claude-configs) plugin).
3) **Profile ALDC-AL-Development** (preconfigured with Javier Armesto Gonzalezs [`ALDC-AL-Development-Collection
`](https://github.com/javiarmesto/ALDC-AL-Development-Collection) plugin).


## Credits

This project is a fork of [StefanMaron/claudeCodeAlDevContainer](https://github.com/StefanMaron/claudeCodeAlDevContainer) by [Stefan Maron](https://github.com/StefanMaron). The core sandbox architecture, security hardening, firewall design, and AL development plugin all originate from his work. Many thanks to Stefan for laying the foundation that made this project possible.


## Setup

### Prerequisites

- Windows 10 (build 19041+) or Windows 11
- WSL2
- A Claude account type that supports Claude Code
- [Windows Terminal](https://aka.ms/terminal)


### Install

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


### Uninstall

> **Note:** VS Code must be started **Run as Administrator** for tasks to work correctly.

Run the VS Code task **claudeCodeWinDocker: Uninstall** (requires VS Code started as Administrator), or run as Administrator:


A confirmation prompt is shown before any destructive action. Removes Claude Code, Ubuntu from WSL2, and disables the WSL2 Windows features. A reboot is required.


## Running the sandbox

### Via VS Code

> **Note:** VS Code must be started **Run as Administrator** for tasks to work correctly.

`Ctrl+Shift+P` → **Tasks: Run Task** → **claudeCodeWinDocker: Run**.

This opens a new Windows Terminal tab, launches WSL2, and starts the container.

The Docker image (`claude-code-sandbox`) is built automatically on first run.

This setup works on workspace and folder (app) level.
Tasks are defined in the workspace & tasks.json. Remove the ones that are obolete in your setup.
Folders always reside on top-level, the app folders contains [symbolic links](https://www.howtogeek.com/16226/complete-guide-to-symbolic-links-symlinks-on-windows-or-linux/) that refer to those top-level folders/files.

### Profile selection

On launch you choose:

```
1) Vanilla Claude Code
2) Claude Code with AL Development profile (Stefan Maron)
3) Claude Code with ALDC profile (Javier Armesto)
```


### Mounts

| Host (WSL2) | Container | Notes |
|---|---|---|
| Current directory | `/workspaces/project` | Your project files |
| `claude-code-data` (Docker volume) | `/home/vscode/.claude` | Claude config, plugin state, and onboarding flags, persisted across runs |
| `~/.config/git/config` (if exists) | `/home/vscode/.gitconfig` | Git identity, read-only |

The `claude-configs` plugin sources are baked into the image at `/home/vscode/claude-configs/` and not mounted from the host.



## Rebuilding the image

> **Note:** VS Code must be started **Run as Administrator** for tasks to work correctly.

After modifying any file under `scripts/claudeCodeAlDevContainer/container/`, clear the image via VS Code task **claudeCodeWinDocker: Clear Docker Image**. Which removes the image so the next run rebuilds it.

Fetching external repos happens when building the Docker Image, a refresh of those repo's also requires a rebuild of the image.



## Why Docker on WSL2 instead of Docker Desktop?

Docker Engine can run on Windows, but in that configuration it only supports Windows containers. This sandbox is built on Ubuntu and requires Linux containers, so Docker Engine on Windows alone is not an option. WSL2 provides the Linux environment needed to run Docker Engine with Linux container support on a Windows machine.

Beyond that, the sandbox relies on Linux kernel features that Docker Desktop does not expose reliably:

- **iptables / ipset / ip6tables** — used to enforce egress firewall rules inside the container. These require direct access to the Linux kernel networking stack.
- **NET_ADMIN / NET_RAW capabilities** — needed so the container can configure its own firewall on startup. These work correctly when Docker runs natively inside WSL2.
- **chattr +i** — makes the firewall and hardening scripts immutable so the agent cannot tamper with them. Requires an ext4 filesystem, which WSL2's virtual disk provides.
- **No licensing cost** — Docker Engine inside WSL2 is free with no commercial license requirements.

Docker Desktop abstracts the Linux kernel behind its own VM in a way that breaks these mechanisms. Running Docker directly inside WSL2 (Ubuntu) gives the container a real Linux kernel and makes the security guarantees reliable.
