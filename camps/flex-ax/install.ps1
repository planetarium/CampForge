# Installer for flex-ax camp (Windows/PowerShell)
# Usage: irm https://raw.githubusercontent.com/planetarium/CampForge/main/camps/flex-ax/install.ps1 | iex
$ErrorActionPreference = 'Stop'

$CampVersion = if ($env:CAMP_VERSION) { $env:CAMP_VERSION } else { "v1.1.0" }
$Base = "https://github.com/planetarium/CampForge/releases/download/flex-ax-$CampVersion"

$WS = if ($env:WORKSPACE) { $env:WORKSPACE } else { "workspace" }
New-Item -ItemType Directory -Force -Path $WS | Out-Null
Push-Location $WS

try {
    npm init -y --silent 2>$null
    npm pkg set `
        "dependencies.@campforge/flex-query=$Base/campforge-flex-query-0.1.0.tgz" `
        "dependencies.@campforge/flex-crawl=$Base/campforge-flex-crawl-0.1.0.tgz" `
        "dependencies.@campforge/gws-auth=$Base/campforge-gws-auth-0.1.0.tgz" `
        "dependencies.@campforge/gws-sheets=$Base/campforge-gws-sheets-0.1.0.tgz" `
        "dependencies.@campforge/gws-gmail=$Base/campforge-gws-gmail-0.1.0.tgz" `
        "dependencies.@campforge/gws-drive=$Base/campforge-gws-drive-0.1.0.tgz"

    npx skillpm install

    # Dot-source shared install helpers
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $Common = Join-Path $ScriptDir "..\..\scripts\install-common.ps1"
    if ($ScriptDir -and (Test-Path $Common)) {
        . $Common
    }
    else {
        $TmpCommon = Join-Path ([System.IO.Path]::GetTempPath()) "install-common.ps1"
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/planetarium/CampForge/flex-ax-$CampVersion/scripts/install-common.ps1" -OutFile $TmpCommon -UseBasicParsing
        . $TmpCommon
        Remove-Item -Force $TmpCommon -ErrorAction SilentlyContinue
    }

    Install-FlexAx
    Install-Gws
    Install-GwsAuth
    Install-CampFiles -Url "$Base/camp-flex-ax.tgz"
    Generate-Adapters

    # Install freshness check script
    $FreshnessScript = "scripts\check-freshness.sh"
    if (Test-Path $FreshnessScript) {
        Write-Host ":: Freshness check already exists"
    }
    elseif (Test-Path "C:\srv\camp-flex-ax.tgz") {
        # Extract from camp tarball (remote install)
        tar xzf "C:\srv\camp-flex-ax.tgz" $FreshnessScript 2>$null
    }

    # Set up platform-specific data freshness hooks
    $Platform = Detect-Platform
    switch ($Platform) {
        "claude-code" {
            $CheckCmd = Join-Path (Get-Location) "scripts\check-freshness.sh"
            if (Test-Path ".claude\settings.json") {
                Write-Host "  [action-required] Add this hook to .claude\settings.json:"
            }
            else {
                New-Item -ItemType Directory -Force -Path ".claude" | Out-Null
                $hookJson = @"
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "command": "bash $CheckCmd",
        "description": "Check flex-ax data freshness and crawl if stale"
      }
    ]
  }
}
"@
                Set-Content -Path ".claude\settings.json" -Value $hookJson -Encoding UTF8
                Write-Host "  Created .claude\settings.json with freshness check hook"
            }
        }
        "openclaw" {
            if (-not (Test-Path "BOOT.md")) {
                $bootContent = @"
Run this command to check if flex-ax data needs refreshing:

``````bash
bash scripts/check-freshness.sh
``````
"@
                Set-Content -Path "BOOT.md" -Value $bootContent -Encoding UTF8
                Write-Host "  Created BOOT.md with freshness check"
            }
            else {
                Write-Host "  [action-required] Existing BOOT.md found. Add freshness check manually."
            }
        }
    }

    Write-Host "flex-ax camp installed"
}
finally {
    Pop-Location
}
