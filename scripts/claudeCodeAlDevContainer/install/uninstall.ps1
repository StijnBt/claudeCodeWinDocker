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


Write-Host "*** REBOOT REQUIRED ***" -ForegroundColor Cyan
