
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
    Write-Host "Accept proposed username so it alligns with Windows." -ForegroundColor Cyan
    & wsl.exe --install -d Ubuntu --no-launch
    if ($LASTEXITCODE -ne 0) {
        Write-Error 'Failed to install Ubuntu. Please confirm WSL2 is enabled and rerun the script.'
        exit 1
    }
    Write-Host 'Ubuntu installed. A new window will open for initial Ubuntu setup.' -ForegroundColor Yellow
    Write-Host 'Create your Linux username and password there, then close that window.' -ForegroundColor Yellow
    Start-Process wsl.exe -ArgumentList '-d Ubuntu'
    Read-Host 'Press Enter here once you have completed Ubuntu setup and closed the Ubuntu window'
}

function Invoke-WslFile {
    param([string]$ScriptPath, [string[]]$Arguments = @())

    # Convert Windows path to WSL path format: C:\path\to\file -> /mnt/c/path/to/file
    $drive = $ScriptPath.Substring(0, 1).ToLower()
    $pathWithoutDrive = $ScriptPath.Substring(2) -replace '\\', '/'
    $wslPath = "/mnt/$drive$pathWithoutDrive"

    # Build quoted argument list for bash -s
    $argStr = ($Arguments | ForEach-Object { "'$($_ -replace "'", "'\''")'" }) -join ' '

    # Strip any CRLF from the script file before piping into bash
    & wsl.exe -d Ubuntu -- bash -c "tr -d '\r' < '$wslPath' | bash -s -- $argStr"
    if ($LASTEXITCODE -ne 0) {
        throw 'WSL script failed. Review the output above for details.'
    }
}

function Install-DockerInWsl {
    Write-Host 'Installing Docker Engine inside Ubuntu WSL...' -ForegroundColor Cyan
    Write-Host 'Ignore Docker Desktop for Windows recommendation & wait for automatic time-out of sleep' -ForegroundColor Cyan

    Invoke-WslFile -ScriptPath "$PSScriptRoot\install-docker.sh"

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

function Install-ClaudeConfigs {
    Write-Host 'Cloning StefanMaron/claude-configs into Ubuntu WSL...' -ForegroundColor Cyan

    Invoke-WslFile -ScriptPath "$PSScriptRoot\install-claude-configs.sh"

    Write-Host 'claude-configs installed in Ubuntu WSL.' -ForegroundColor Green
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

    $existingName = wsl -d Ubuntu -- bash -c 'git config --global user.name  2>/dev/null' 2>$null
    $existingEmail = wsl -d Ubuntu -- bash -c 'git config --global user.email 2>/dev/null' 2>$null

    if (-not [string]::IsNullOrWhiteSpace($existingName) -or -not [string]::IsNullOrWhiteSpace($existingEmail)) {
        Write-Host "Git is already configured in WSL:" -ForegroundColor Yellow
        Write-Host "  user.name  = $existingName"  -ForegroundColor Yellow
        Write-Host "  user.email = $existingEmail" -ForegroundColor Yellow
        $reconfigure = Read-Host 'Reconfigure? [Y/N]'
        if ($reconfigure.Trim().ToLower() -notin @('y', 'yes')) {
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

    Invoke-WslFile -ScriptPath "$PSScriptRoot\configure-git.sh" -Arguments @($gitName, $gitEmail)
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

    Write-Section 'Step 6: Install Claude Configs (AL Development plugins)'
    Install-ClaudeConfigs

    Write-Host "`nInstallation sequence completed." -ForegroundColor Green
    Write-Host "If Docker was installed, open a new WSL terminal before using Docker commands." -ForegroundColor Cyan
    Read-Host "`nPress Enter to exit"
}

Main
