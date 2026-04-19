
[CmdletBinding()]
param(
    [switch]$SkipClaude,
    [switch]$SkipDocker
)

function Ensure-RunAsAdministrator {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "This script must be run as Administrator. Right-click PowerShell and choose 'Run as administrator'."
        exit 1
    }
}

function Write-Section {
    param([string]$Text)
    Write-Host "`n=== $Text ===" -ForegroundColor Cyan
}

function Enable-WSL2Features {
    $features = @(
        'Microsoft-Windows-Subsystem-Linux',
        'VirtualMachinePlatform'
    )

    $needsEnable = @()
    foreach ($feature in $features) {
        $state = (Get-WindowsOptionalFeature -Online -FeatureName $feature -ErrorAction SilentlyContinue).State
        if ($state -ne 'Enabled') {
            $needsEnable += $feature
        }
    }

    if ($needsEnable.Count -eq 0) {
        Write-Host 'WSL2 features are already enabled.' -ForegroundColor Green
        return
    }

    foreach ($feature in $needsEnable) {
        Write-Host "Enabling $feature..."
        dism.exe /online /enable-feature /featurename:$feature /all /norestart | Out-Null
    }

    Write-Host "WSL2 features have been enabled. A reboot is required before continuing." -ForegroundColor Yellow
    Write-Host "Please reboot and run this script again." -ForegroundColor Green
    exit 0
}

function Ensure-UbuntuDistro {
    $distrosOutput = & wsl.exe --list --quiet 2>&1
    $distros = $distrosOutput | ForEach-Object {
        $line = $_ -replace '\x00', ''  # Remove null bytes from UTF-16 encoding
        $line.Trim()
    } | Where-Object { $_ -match '^Ubuntu' }

    if ($distros) {
        Write-Host 'Ubuntu distribution is already installed.' -ForegroundColor Green
        return
    }

    Write-Host 'Installing Ubuntu distribution...' -ForegroundColor Cyan
    Write-Host "Ubuntu installation started. You may be prompted to create a Linux username and password." -ForegroundColor Yellow
    Write-Host "After installation completes, close this PowerShell session, reopen it as Administrator, and rerun this script." -ForegroundColor Green
    & wsl.exe --install -d Ubuntu
    if ($LASTEXITCODE -ne 0) {
        Write-Error 'Failed to install Ubuntu. Please confirm WSL2 is enabled and rerun the script.'
        exit 1
    }
    exit 0
}

function Invoke-WslScript {
    param([string]$Script)

    # Write script to Windows temp, execute via WSL
    $winTemp = $env:TEMP
    $scriptName = "wsl-script-$(Get-Random).sh"
    $winPath = Join-Path $winTemp $scriptName

    # Convert Windows path to WSL path format: C:\path\to\file -> /mnt/c/path/to/file
    $pathWithoutDrive = $winPath.Substring(2) -replace '\\', '/'  # Remove drive letter and convert slashes
    $wslPath = "/mnt/$($winPath.Substring(0, 1).ToLower())$pathWithoutDrive"

    # Write with Unix line endings - remove all CR characters and ensure only LF
    $unixScript = $Script -replace "`r`n", "`n" -replace "`r", "`n"
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($winPath, $unixScript, $utf8NoBom)

    try {
        # Execute from WSL, stripping any remaining CR characters with tr
        & wsl.exe -d Ubuntu -- bash -c "tr -d '\r' < '$wslPath' | bash"
        if ($LASTEXITCODE -ne 0) {
            throw 'WSL command failed. Review the output above for details.'
        }
    }
    finally {
        Remove-Item $winPath -Force -ErrorAction SilentlyContinue
    }
}

function Install-DockerInWsl {
    Write-Host 'Installing Docker Engine inside Ubuntu WSL...' -ForegroundColor Cyan
    Write-Host 'Ignore Docker Desktop for Windows recommendation & wait for automatic time-out of sleep' -ForegroundColor Cyan

    $script = @'
#!/bin/bash
set -e

curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
rm get-docker.sh
sudo usermod -aG docker "$USER"
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

sudo rm -f /etc/sudoers.d/docker-autostart
sudo bash -lc 'echo "JWRvY2tlciBBTEw9KEFMTCkgTk9QQVNTV0Q6IC91c3Ivc2Jpbi9zZXJ2aWNlIGRvY2tlciBzdGFydAo=" | base64 -d > /etc/sudoers.d/docker-autostart'
sudo sed -i 's/\r$//' /etc/sudoers.d/docker-autostart
sudo chmod 440 /etc/sudoers.d/docker-autostart

if ! grep -qF '# Docker autostart (added by install.ps1)' ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# Docker autostart (added by install.ps1)" >> ~/.bashrc
    echo 'if [ "$(service docker status 2>&1 | grep -c '"'"'not running'"'"')" -eq 1 ]; then' >> ~/.bashrc
    echo "    sudo service docker start > /dev/null 2>&1" >> ~/.bashrc
    echo "fi" >> ~/.bashrc
fi

sudo service docker start
sudo docker run --rm hello-world
'@

    Invoke-WslScript -Script $script

    Write-Host "Docker is installed in Ubuntu WSL." -ForegroundColor Green
    Write-Host "Open a new WSL terminal to use Docker without requiring a new login session." -ForegroundColor Yellow
}

function Install-ClaudeCode {
    Write-Host 'Installing Claude Code on Windows...' -ForegroundColor Cyan
    irm https://claude.ai/install.ps1 | iex

    $claudePath = "$env:USERPROFILE\.local\bin"
    $currentPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($currentPath -notlike "*${claudePath}*") {
        [Environment]::SetEnvironmentVariable('Path', "$currentPath;$claudePath", 'User')
        Write-Host "Added $claudePath to user PATH." -ForegroundColor Green
    }
    else {
        Write-Host "Claude Code path already present in user PATH." -ForegroundColor Green
    }
}

function Confirm-InstallClaudeCode {
    if ($SkipClaude) {
        return $false
    }

    while ($true) {
        $answer = Read-Host 'Install Claude Code locally on this Windows machine? [Y/N]'
        switch ($answer.Trim().ToLower()) {
            'y' { return $true }
            'yes' { return $true }
            'n' { return $false }
            'no' { return $false }
            default { Write-Host 'Please answer Y or N.' -ForegroundColor Yellow }
        }
    }
}


function Configure-GitInWsl {
    Write-Host 'Configuring Git user settings in Ubuntu WSL...' -ForegroundColor Cyan

    $existingName  = wsl -d Ubuntu -- bash -c 'git config --global user.name  2>/dev/null' 2>$null
    $existingEmail = wsl -d Ubuntu -- bash -c 'git config --global user.email 2>/dev/null' 2>$null

    if (-not [string]::IsNullOrWhiteSpace($existingName) -or -not [string]::IsNullOrWhiteSpace($existingEmail)) {
        Write-Host "Git is already configured in WSL:" -ForegroundColor Yellow
        Write-Host "  user.name  = $existingName"  -ForegroundColor Yellow
        Write-Host "  user.email = $existingEmail" -ForegroundColor Yellow
        $reconfigure = Read-Host 'Reconfigure? [Y/N]'
        if ($reconfigure.Trim().ToLower() -notin @('y','yes')) {
            Write-Host 'Git configuration skipped.' -ForegroundColor Yellow
            return
        }
    }

    $gitName = Read-Host 'Enter Git user.name (leave blank to skip)'
    $gitEmail = Read-Host 'Enter Git user.email (leave blank to skip)'

    if ([string]::IsNullOrWhiteSpace($gitName) -and [string]::IsNullOrWhiteSpace($gitEmail)) {
        Write-Host 'No Git user settings provided, skipping Git configuration.' -ForegroundColor Yellow
        return
    }

    $escapedName = $gitName -replace "'", "'\"'\"'"
    $escapedEmail = $gitEmail -replace "'", "'\"'\"'"

    $script = @"
#!/bin/bash
set -e
if ! command -v git >/dev/null 2>&1; then
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y git
fi
if [ -n '$escapedName' ]; then
    git config --global user.name '$escapedName'
fi
if [ -n '$escapedEmail' ]; then
    git config --global user.email '$escapedEmail'
fi
"@

    Invoke-WslScript -Script $script
    Write-Host 'Git configuration completed in Ubuntu WSL.' -ForegroundColor Green
}

function Main {
    Ensure-RunAsAdministrator
    Write-Section 'Step 1: Enable WSL2'
    Enable-WSL2Features

    Write-Section 'Step 2: Install Ubuntu WSL'
    Ensure-UbuntuDistro


    Write-Section 'Step 3: Configure Git in Ubuntu WSL'
    Configure-GitInWsl


    if (-not $SkipDocker) {
        Write-Section 'Step 4: Install Docker in Ubuntu WSL'
        Install-DockerInWsl
    }
    else {
        Write-Host 'Skipping Docker installation as requested.' -ForegroundColor Yellow
    }


    Write-Section 'Step 5: Install Claude Code [Optional]'
    if (Confirm-InstallClaudeCode) {
        Install-ClaudeCode
    }
    else {
        Write-Host 'Claude Code installation skipped.' -ForegroundColor Yellow
    }

    Write-Host "`nInstallation sequence completed." -ForegroundColor Green
    Write-Host "If Docker was installed, open a new WSL terminal before using Docker commands." -ForegroundColor Cyan
    Write-Host "To build the sandbox image from the repository root, run:`n  docker build -t claude-code-sandbox -f standalone/Dockerfile ." -ForegroundColor Cyan
}

Main
