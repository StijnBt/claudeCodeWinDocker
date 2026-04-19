#Requires -RunAsAdministrator

Write-Host "[1/4]: Uninstalling Claude Code Local..." -ForegroundColor Cyan

# Remove Claude Code binaries
Remove-Item -Path "$env:USERPROFILE\.local\bin\claude.exe" -Force -ErrorAction SilentlyContinue

# Remove Claude Code config/folders
Remove-Item -Path "$env:USERPROFILE\.claude" -Recurse -Force -ErrorAction SilentlyContinue

# Remove from PATH (User variable)
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
$newPath = ($currentPath -split ";" | Where-Object { $_ -notmatch "\.local\\bin" }) -join ";"
[Environment]::SetEnvironmentVariable("Path", $newPath, "User")


Write-Host "[2/4]: Uninstalling Ubuntu from WSL2..." -ForegroundColor Cyan
wsl --unregister Ubuntu


Write-Host "[3/4]: Disabling WSL2 features..." -ForegroundColor Cyan
dism.exe /online /disable-feature /featurename:Microsoft-Windows-Subsystem-Linux /norestart


Write-Host "[4/4]: Disabling Virtual Machine Platform features..." -ForegroundColor Cyan
dism.exe /online /disable-feature /featurename:VirtualMachinePlatform /norestart



# Confirm and remove any remaining local Claude Code installation
$claudeBinary = Join-Path $env:USERPROFILE ".local\bin\claude.exe"
$claudeHome = Join-Path $env:USERPROFILE ".claude"
if ((Test-Path $claudeBinary) -or (Test-Path $claudeHome)) {
    $confirm = Read-Host "Claude Code appears installed locally. Remove remaining local files? (Y/N)"
    if ($confirm -match '^[Yy]$') {
        Remove-Item -Path $claudeBinary -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $claudeHome -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Removed remaining local Claude Code files." -ForegroundColor Cyan
    }
    else {
        Write-Host "Skipped removing remaining local Claude Code files." -ForegroundColor Yellow
    }
}
else {
    Write-Host "No local Claude Code installation detected." -ForegroundColor Yellow
}


Write-Host "*** REBOOT REQUIRED ***" -ForegroundColor Cyan
