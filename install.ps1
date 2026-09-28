<#
.SYNOPSIS
    Bootstraps this dotfiles repo onto a new Windows machine.

.DESCRIPTION
    Copies bash config, oh-my-posh themes, and the pokecow
    fortune/cowsay-sprite greeting into place, sets the MSYS2_ROOT user
    environment variable, points MSYS2's home directory at the Windows user
    folder (db_home: windows in nsswitch.conf), then merges the "Bash" Windows Terminal profile
    (MSYS2 UCRT64 + Tokyo Night + FiraCode Nerd Font) into Windows Terminal's
    settings.json.

    Does NOT download or install any fonts - install FiraCode Nerd Font
    manually (see the steps printed at the end).

    Safe to re-run: existing target files are backed up with a .bak-<timestamp>
    suffix before being overwritten, and the Windows Terminal merge skips any
    profile/scheme that already exists (matched by guid / name).

.PARAMETER Msys2Root
    MSYS2 install folder, stored in the MSYS2_ROOT user environment variable
    that the "Bash" profile launches from. Defaults to the MSYS2 installer's
    default, C:\msys64. Ignored if MSYS2_ROOT is already set.

.NOTES
    Install MSYS2 first. Then, from PowerShell:
        powershell -ExecutionPolicy Bypass -File install.ps1 [-Msys2Root C:\msys2]
    (or right-click -> Run with PowerShell)
#>

param(
    [string]$Msys2Root = "C:\msys64"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

function Backup-IfExists([string]$Path) {
    if (Test-Path $Path) {
        $backup = "$Path.bak-$Timestamp"
        Copy-Item -Path $Path -Destination $backup -Force
        Write-Host "  backed up existing $Path -> $backup" -ForegroundColor DarkGray
    }
}

function Install-File([string]$Source, [string]$Dest) {
    # Skip (and don't back up) when the file is already up to date, so re-runs
    # don't litter the home folder with identical .bak copies.
    if ((Test-Path $Dest) -and (Get-FileHash $Source).Hash -eq (Get-FileHash $Dest).Hash) {
        Write-Host "  $Dest already up to date" -ForegroundColor DarkGray
        return
    }
    Backup-IfExists $Dest
    Copy-Item $Source $Dest -Force
    Write-Host "  installed $Dest"
}

function Copy-Into([string]$Source, [string]$DestDir, [switch]$Recurse) {
    New-Item -ItemType Directory -Force -Path $DestDir | Out-Null
    if ($Recurse) {
        Copy-Item -Path (Join-Path $Source '*') -Destination $DestDir -Recurse -Force
    } else {
        Copy-Item -Path $Source -Destination $DestDir -Force
    }
}

Write-Host "== 1. Bash config ==" -ForegroundColor Cyan
Install-File "$RepoRoot\bash\.bashrc" "$HOME\.bashrc"
Install-File "$RepoRoot\bash\.bash_profile" "$HOME\.bash_profile"

Write-Host "== 2. oh-my-posh themes ==" -ForegroundColor Cyan
Copy-Into "$RepoRoot\oh-my-posh" "$HOME\.config\oh-my-posh" -Recurse
Write-Host "  themes copied to $HOME\.config\oh-my-posh"

Write-Host "== 3. pokecow (fortune + pokemon sprite greeting) ==" -ForegroundColor Cyan
Copy-Into "$RepoRoot\pokecow\pokesay.sh" "$HOME\.config\cowsay"
Copy-Into "$RepoRoot\pokecow\cows" "$HOME\.config\cowsay\pokemons" -Recurse
Write-Host "  pokesay.sh -> $HOME\.config\cowsay, cows -> $HOME\.config\cowsay\pokemons"

Write-Host "== 4. MSYS2_ROOT environment variable ==" -ForegroundColor Cyan
$existingRoot = [Environment]::GetEnvironmentVariable("MSYS2_ROOT", "User")
if ($existingRoot) {
    Write-Host "  MSYS2_ROOT already set to $existingRoot, left as-is" -ForegroundColor DarkGray
} else {
    [Environment]::SetEnvironmentVariable("MSYS2_ROOT", $Msys2Root, "User")
    Write-Host "  set MSYS2_ROOT=$Msys2Root (user scope)"
}
$effectiveRoot = [Environment]::GetEnvironmentVariable("MSYS2_ROOT", "User")
if (-not (Test-Path (Join-Path $effectiveRoot "msys2_shell.cmd"))) {
    Write-Host "  warning: $effectiveRoot\msys2_shell.cmd not found - install MSYS2 there, or re-run with -Msys2Root <path> after clearing MSYS2_ROOT" -ForegroundColor Yellow
}

Write-Host "== 5. MSYS2 home = Windows user folder ==" -ForegroundColor Cyan
# Everything above is copied into $HOME (C:\Users\<you>), but MSYS2 defaults
# to its own home (<MSYS2_ROOT>\home\<you>). Point MSYS2's ~ at the Windows
# user folder so the shell actually finds .bashrc and ~/.config.
$nsswitch = Join-Path $effectiveRoot "etc\nsswitch.conf"
if (-not (Test-Path $nsswitch)) {
    Write-Host "  $nsswitch not found - install MSYS2 first, then re-run this script" -ForegroundColor Yellow
} else {
    $conf = [IO.File]::ReadAllText($nsswitch)
    if ($conf -match '(?m)^db_home:\s*windows\s*$') {
        Write-Host "  db_home already set to windows, skipped" -ForegroundColor DarkGray
    } else {
        Backup-IfExists $nsswitch
        if ($conf -match '(?m)^db_home:') {
            $conf = $conf -replace '(?m)^db_home:.*$', 'db_home: windows'
        } else {
            $conf = $conf.TrimEnd("`n") + "`ndb_home: windows`n"
        }
        [IO.File]::WriteAllText($nsswitch, $conf, (New-Object Text.UTF8Encoding $false))
        Write-Host "  set db_home: windows in $nsswitch"
    }
}

Write-Host "== 6. Windows Terminal profile merge ==" -ForegroundColor Cyan
$wtPackageDir = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe"
$wtSettingsPath = "$wtPackageDir\LocalState\settings.json"
if (-not (Test-Path $wtPackageDir)) {
    Write-Host "  Windows Terminal isn't installed - skipping. Install it, then re-run this script." -ForegroundColor Yellow
} else {
    $fragment = Get-Content "$RepoRoot\windows-terminal\profile-fragment.json" -Raw | ConvertFrom-Json
    $changed = $false
    if (Test-Path $wtSettingsPath) {
        $settings = Get-Content $wtSettingsPath -Raw | ConvertFrom-Json
    } else {
        $changed = $true
        # Never launched: start from an empty settings file. Windows Terminal
        # fills in its default profiles and settings around it on first launch.
        New-Item -ItemType Directory -Force -Path (Split-Path $wtSettingsPath) | Out-Null
        $settings = '{ "$schema": "https://aka.ms/terminal-profiles-schema", "profiles": { "list": [] }, "schemes": [] }' | ConvertFrom-Json
        Write-Host "  no settings.json yet - creating one"
    }

    foreach ($wtProfile in $fragment.profiles) {
        if (-not ($settings.profiles.list | Where-Object { $_.guid -eq $wtProfile.guid })) {
            $settings.profiles.list += $wtProfile
            $changed = $true
            Write-Host "  added '$($wtProfile.name)' profile"
        } else {
            Write-Host "  '$($wtProfile.name)' profile already present, skipped"
        }
    }

    # Check the property exists, not its value - an empty "schemes": [] is falsy.
    if ($settings.PSObject.Properties.Name -notcontains "schemes") {
        $settings | Add-Member -MemberType NoteProperty -Name schemes -Value @()
    }
    foreach ($scheme in $fragment.schemes) {
        if (-not ($settings.schemes | Where-Object { $_.name -eq $scheme.name })) {
            $settings.schemes += $scheme
            $changed = $true
            Write-Host "  added '$($scheme.name)' color scheme"
        } else {
            Write-Host "  '$($scheme.name)' color scheme already present, skipped"
        }
    }

    if ($changed) {
        Backup-IfExists $wtSettingsPath
        ($settings | ConvertTo-Json -Depth 20) | Set-Content -Path $wtSettingsPath -Encoding utf8
        Write-Host "  merged into $wtSettingsPath"
    } else {
        Write-Host "  settings.json already up to date" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "== Manual steps still required ==" -ForegroundColor Yellow
Write-Host "  1. Install MSYS2 (https://www.msys2.org/) if you haven't - then RE-RUN this script"
Write-Host "     so step 5 can set its home folder. In the UCRT64 shell run:"
Write-Host "       pacman -S --needed mingw-w64-ucrt-x86_64-fortune-mod mingw-w64-ucrt-x86_64-cowsay mingw-w64-ucrt-x86_64-oh-my-posh"
Write-Host "     Use this oh-my-posh, not the winget one -"
Write-Host "     the winget build is an MSIX app whose alias hangs when run from MSYS2."
Write-Host "  2. Install FiraCode Nerd Font yourself from https://www.nerdfonts.com/font-downloads"
Write-Host "     (unzip, select the .ttf files, right-click -> Install)."
Write-Host "  3. Fully close and reopen Windows Terminal so it picks up MSYS2_ROOT."
Write-Host "  4. Open Windows Terminal -> Settings -> Startup, set default profile to 'Bash'."
Write-Host "  5. Open a new 'Bash' tab and confirm you get a random Pokemon + fortune greeting."
Write-Host ""
Write-Host "Done." -ForegroundColor Green
