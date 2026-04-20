# ==============================================================================
# update-all.ps1
#
# A maintenance script that updates all package managers and tools across
# both Windows and WSL Ubuntu in one run.
#
# What it updates:
#   - Scoop buckets (package index)
#   - All Scoop-installed apps (includes Node.js)
#   - WSL Ubuntu packages (apt)
#   - Ubuntu kernel and system packages (dist-upgrade)
#   - Node.js LTS in WSL (via nvm)
#
# It also checks if a new Ubuntu release is available and reminds
# you to upgrade manually if so.
#
# Usage:
#   Double-click update-all.bat  (recommended)
#   OR from a PowerShell terminal:
#   powershell -ExecutionPolicy Bypass -File update-all.ps1
# ==============================================================================


# --- Scoop --------------------------------------------------------------------

# Refresh bucket manifests so Scoop knows about the latest available versions
Write-Host "`n==> Updating Scoop buckets..." -ForegroundColor Cyan
scoop update

# Update all installed Scoop apps (includes Node.js and everything else)
Write-Host "`n==> Updating all Scoop apps..." -ForegroundColor Cyan
scoop update *

# Remove old versions of apps that were updated (frees disk space)
Write-Host "`n==> Cleaning up old Scoop versions..." -ForegroundColor Cyan
scoop cleanup *

# Clear the download cache (installers Scoop kept after installing)
scoop cache rm *


# --- WSL Ubuntu ---------------------------------------------------------------

# Runs a multi-step update inside the Ubuntu distro via wsl.exe.
# wsl.exe is a regular Windows binary so PowerShell can call it directly --
# it spins up Ubuntu, runs the commands, and returns.
#
# The bash commands are stored in a variable to avoid PowerShell misreading
# the && operators in a multiline string.
Write-Host "`n==> Updating WSL Ubuntu packages + NVM Node..." -ForegroundColor Cyan

$bashCmd = "sudo apt update && sudo apt upgrade -y && sudo apt dist-upgrade -y && sudo apt autoremove -y && source ~/.nvm/nvm.sh && nvm install --lts && nvm use --lts"
wsl -d Ubuntu -- bash -c $bashCmd


# --- Ubuntu Release Check -----------------------------------------------------

# Checks if a new Ubuntu release is available (e.g. 22.04 -> 24.04).
# Does NOT upgrade automatically -- release upgrades are interactive and
# can break things, so this just notifies you to do it manually when ready.
Write-Host "`n==> Checking for new Ubuntu release..." -ForegroundColor Cyan
$releaseCheck = wsl -d Ubuntu -- bash -c "sudo do-release-upgrade -c 2>&1"
if ($releaseCheck -match "New release") {
    Write-Host "!! A new Ubuntu release is available. Upgrade manually when ready:" -ForegroundColor Yellow
    Write-Host "   wsl -d Ubuntu -- bash -c 'sudo do-release-upgrade'" -ForegroundColor Yellow
} else {
    Write-Host "   Ubuntu is up to date (no new release available)." -ForegroundColor Green
}


# --- Done ---------------------------------------------------------------------
Write-Host "`n==> All done!" -ForegroundColor Green
