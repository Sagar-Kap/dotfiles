# ==============================================================================
# update-all.ps1
#
# A maintenance script that updates all package managers and tools across
# both Windows and WSL Ubuntu in one run.
#
# What it updates:
#   - PowerShell 7 (pwsh) via winget
#   - Scoop buckets (package index)
#   - All Scoop-installed apps (includes Node.js on Windows)
#   - WSL Ubuntu packages (apt upgrade + dist-upgrade)
#   - Node.js LTS in WSL (via nvm)
#   - Homebrew packages in WSL (brew upgrade, if installed)
#
# It also checks if a new Ubuntu release is available and reminds
# you to upgrade manually if so.
#
# Usage:
#   Double-click update-all.bat  (recommended)
#   OR from a PowerShell terminal:
#   powershell -ExecutionPolicy Bypass -File update-all.ps1
#
# Notes:
#   - This script runs as Windows PowerShell 5.1 when launched via .bat.
#     pwsh 7 version is read by spawning a fresh subprocess after winget.
#   - The WSL bash script is written to a temp file inside WSL and then
#     executed. This keeps stdin free so sudo can prompt for a password
#     normally, while also avoiding all CRLF/quoting/escaping issues.
#   - The single-quoted PowerShell here-string @' '@ ensures zero
#     interpolation -- $PATH, $(), etc. reach bash exactly as written.
#   - The Ubuntu Pro / ESM advertisement is suppressed permanently on first
#     run by disabling two systemd services. These calls are idempotent.
#   - Homebrew steps are skipped gracefully if brew is not installed.
#   - Ubuntu release upgrades are intentionally NOT automated.
# ==============================================================================


# --- PowerShell ---------------------------------------------------------------
#
# Upgrades pwsh 7 via winget (the standard install path for most users).
# The running session is Windows PowerShell 5.1 when launched via .bat, so
# we read the pwsh 7 version by spawning a fresh subprocess before and after.

Write-Host "`n==> Checking PowerShell 7 (pwsh) version..." -ForegroundColor Cyan

$psBefore = & pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>$null
if ($psBefore) {
    Write-Host "   Current pwsh: $psBefore" -ForegroundColor Gray
} else {
    Write-Host "   pwsh not found -- it may not be installed yet." -ForegroundColor Yellow
}

Write-Host "`n==> Updating PowerShell 7 via winget..." -ForegroundColor Cyan
winget upgrade --id Microsoft.PowerShell --silent --accept-source-agreements --accept-package-agreements

$psAfter = & pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>$null
if ($psAfter -and $psBefore -and ($psAfter -ne $psBefore)) {
    Write-Host "   Updated: $psBefore -> $psAfter" -ForegroundColor Green
    Write-Host "   Restart this terminal to use the new version." -ForegroundColor Yellow
} elseif ($psAfter) {
    Write-Host "   PowerShell 7 is up to date ($psAfter)." -ForegroundColor Green
}


# --- Scoop --------------------------------------------------------------------

# Refresh bucket manifests so Scoop knows about the latest available versions
Write-Host "`n==> Updating Scoop buckets..." -ForegroundColor Cyan
scoop update

# Update all installed Scoop apps
Write-Host "`n==> Updating all Scoop apps..." -ForegroundColor Cyan
scoop update *

# Remove old versions of apps that were updated (frees disk space)
Write-Host "`n==> Cleaning up old Scoop versions..." -ForegroundColor Cyan
scoop cleanup *

# Clear the download cache (installers Scoop kept after installing)
scoop cache rm *


# --- WSL Ubuntu ---------------------------------------------------------------
#
# Writes a bash script to /tmp/wsl-update.sh inside Ubuntu, executes it,
# then removes it. Writing to a file (rather than piping via stdin or using
# bash -c) keeps stdin connected to the terminal so sudo can prompt for a
# password normally, while avoiding all CRLF and quoting issues.
#
# Steps performed inside Ubuntu:
#   1. Suppress ESM nag         -- disable apt-news/esm-cache + pro config
#                                  (idempotent, no-ops after first run)
#   2. apt update               -- refresh package index
#   3. apt upgrade              -- upgrade installed packages
#   4. apt dist-upgrade         -- upgrade kernel + handle dependency changes
#   5. apt autoremove           -- remove obsolete packages
#   6. nvm install --lts        -- install/upgrade to the latest Node.js LTS
#   7. nvm use --lts            -- switch to it
#   8. brew update/upgrade/cleanup -- skipped gracefully if not installed

Write-Host "`n==> Updating WSL Ubuntu (apt + nvm + brew)..." -ForegroundColor Cyan

# Write the bash script into WSL via a single piped echo.
# Single-quoted @' '@ means PowerShell does zero interpolation.
$wslScript = @'
#!/bin/bash
set -e

# Suppress Ubuntu Pro / ESM advertisement permanently.
# apt -qq intentionally does NOT suppress this (confirmed Ubuntu bug #1992026).
# Disabling these two services is the correct permanent fix.
sudo systemctl disable --now apt-news.service esm-cache.service 2>/dev/null || true
sudo pro config set apt_news=false 2>/dev/null || true

# Update packages
sudo apt update -q
sudo apt upgrade -y
sudo apt dist-upgrade -y
sudo apt autoremove -y

# Node.js via nvm
source ~/.nvm/nvm.sh
nvm install --lts
nvm use --lts

# Homebrew
# Added to PATH explicitly -- non-interactive shell skips ~/.bashrc
export PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"
if command -v brew > /dev/null 2>&1; then
    brew update
    brew upgrade
    brew cleanup
else
    echo "   Homebrew not found in WSL -- skipping brew update."
fi
'@

# Write script to a temp file inside WSL, run it, then clean up
$wslScript | wsl -d Ubuntu -- bash -c "tr -d '\r' > /tmp/wsl-update.sh && chmod +x /tmp/wsl-update.sh"
wsl -d Ubuntu -- bash /tmp/wsl-update.sh
wsl -d Ubuntu -- bash -c "rm /tmp/wsl-update.sh"


# --- Ubuntu Release Check -----------------------------------------------------
#
# Checks if a new Ubuntu release is available (e.g. 22.04 -> 24.04).
# Does NOT upgrade automatically -- release upgrades are interactive and
# can break things, so this just notifies you to do it manually when ready.

Write-Host "`n==> Checking for new Ubuntu release..." -ForegroundColor Cyan

$releaseCheck = wsl -d Ubuntu -- bash -c "sudo do-release-upgrade -c 2>&1"

if ($releaseCheck -match "New release") {
    Write-Host "!! A new Ubuntu release is available. Upgrade manually when ready:" -ForegroundColor Yellow
    Write-Host "   wsl -d Ubuntu -- sudo do-release-upgrade" -ForegroundColor Yellow
} else {
    Write-Host "   Ubuntu is up to date (no new release available)." -ForegroundColor Green
}


# --- Done ---------------------------------------------------------------------

Write-Host "`n==> All done!" -ForegroundColor Green
