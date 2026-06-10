<#
.SYNOPSIS
    Creates symlinks from project paths to .local/ (Nextcloud-synced) equivalents,
    and clones child repos into repos/.
.DESCRIPTION
    Run once after cloning on a new machine, after Nextcloud has synced the .local/ folder.
    Requires Developer Mode enabled on Windows (Settings > Update & Security > For developers).
#>
param(
    [switch]$Force,
    [switch]$SkipRepos
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

# --- Symlinks ---

$links = @(
    @{ Link = "$root\.env";                            Target = "$root\.local\.env" }
    @{ Link = "$root\.claude\settings.local.json";     Target = "$root\.local\.claude\settings.local.json" }
    @{ Link = "$root\reference\CREDENTIALS.md";        Target = "$root\.local\reference\CREDENTIALS.md" }
)

if (-not (Test-Path "$root\.local")) {
    Write-Error ".local/ directory not found. Set up Nextcloud sync for this project's .local/ folder first."
    exit 1
}

foreach ($item in $links) {
    $link = $item.Link
    $target = $item.Target

    if (-not (Test-Path $target)) {
        Write-Warning "Target not found, skipping: $target"
        continue
    }

    $parentDir = Split-Path -Parent $link
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Force $parentDir | Out-Null
    }

    if (Test-Path $link) {
        $existing = Get-Item $link
        if ($existing.LinkType -eq 'SymbolicLink') {
            Write-Host "Already linked: $link" -ForegroundColor DarkGray
            continue
        }
        if ($Force) {
            Remove-Item $link -Force
        } else {
            Write-Warning "File exists and is not a symlink: $link (use -Force to overwrite)"
            continue
        }
    }

    cmd /c mklink "$link" "$target" | Out-Null
    Write-Host "Linked: $link -> $target" -ForegroundColor Green
}

# --- Child repos ---

if (-not $SkipRepos) {
    $repos = @(
        @{ Name = "weewx-clearskies-api";           Url = "https://github.com/inguy24/weewx-clearskies-api.git" }
        @{ Name = "weewx-clearskies-dashboard";      Url = "https://github.com/inguy24/weewx-clearskies-dashboard.git" }
        @{ Name = "weewx-clearskies-design-tokens";  Url = "https://github.com/inguy24/weewx-clearskies-design-tokens.git" }
        @{ Name = "weewx-clearskies-realtime";       Url = "https://github.com/inguy24/weewx-clearskies-realtime.git" }
        @{ Name = "weewx-clearskies-stack";          Url = "https://github.com/inguy24/weewx-clearskies-stack.git" }
    )

    foreach ($repo in $repos) {
        $dest = "$root\repos\$($repo.Name)"
        if (Test-Path "$dest\.git") {
            Write-Host "Already cloned: repos/$($repo.Name)" -ForegroundColor DarkGray
            continue
        }
        Write-Host "Cloning repos/$($repo.Name)..." -ForegroundColor Cyan
        git clone $repo.Url $dest
    }
}

Write-Host "`nDone." -ForegroundColor Cyan
