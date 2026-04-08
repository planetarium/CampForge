# Common installation functions for CampForge camps (Windows/PowerShell).
# Dot-sourced by each camp's install.ps1 — not executed directly.

$ErrorActionPreference = 'Stop'

# Install flex-ax CLI from GitHub Release.
function Install-FlexAx {
    $version = if ($env:FLEX_AX_VERSION) { $env:FLEX_AX_VERSION } else { "0.2.0" }
    $tag = "flex-cli@$version"
    $tgz = "flex-ax-$version.tgz"
    $url = "https://github.com/planetarium/flex-ax/releases/download/$tag/$tgz"

    Write-Host ":: Installing flex-ax CLI ($tag)..."

    if (Get-Command flex-ax -ErrorAction SilentlyContinue) {
        Write-Host "  flex-ax already installed, skipping."
        return
    }

    $prefix = Join-Path (Get-Location) ".local"
    $binDir = Join-Path $prefix "bin"
    New-Item -ItemType Directory -Force -Path $prefix | Out-Null
    New-Item -ItemType Directory -Force -Path $binDir | Out-Null

    # Ensure npm roaming directory exists
    $npmRoaming = Join-Path $env:APPDATA "npm"
    if (-not (Test-Path $npmRoaming)) {
        New-Item -ItemType Directory -Force -Path $npmRoaming | Out-Null
    }

    $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
    New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null

    try {
        $tgzPath = Join-Path $tmpDir $tgz
        Invoke-WebRequest -Uri $url -OutFile $tgzPath -UseBasicParsing -ErrorAction Stop

        npm install --prefix $prefix $tgzPath 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  [warn] flex-ax npm install failed."
            return
        }

        # Create .cmd wrapper in .local/bin/
        $cliJs = Join-Path $prefix "node_modules" "flex-ax" "dist" "cli.js"
        if (Test-Path $cliJs) {
            $cmdWrapper = Join-Path $binDir "flex-ax.cmd"
            Set-Content -Path $cmdWrapper -Value "@echo off`r`nnode `"$cliJs`" %*"
        }

        $env:Path = "$binDir;$($env:Path)"
        Write-Host "  flex-ax installed at $binDir\flex-ax.cmd"
    }
    finally {
        Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
    }
}

# Install Google Workspace CLI (gws).
function Install-Gws {
    Write-Host ":: Installing gws..."

    if (Get-Command gws -ErrorAction SilentlyContinue) {
        Write-Host "  gws already installed, skipping."
        return
    }

    $prefix = Join-Path (Get-Location) ".local"
    $binDir = Join-Path $prefix "bin"
    New-Item -ItemType Directory -Force -Path $prefix | Out-Null
    New-Item -ItemType Directory -Force -Path $binDir | Out-Null

    # Ensure npm roaming directory exists
    $npmRoaming = Join-Path $env:APPDATA "npm"
    if (-not (Test-Path $npmRoaming)) {
        New-Item -ItemType Directory -Force -Path $npmRoaming | Out-Null
    }

    # npm install to workspace-local prefix
    npm install --prefix $prefix @googleworkspace/cli 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [warn] gws install failed."
        return
    }

    $cliJs = Join-Path $prefix "node_modules" "@googleworkspace" "cli" "run.js"
    if (Test-Path $cliJs) {
        $cmdWrapper = Join-Path $binDir "gws.cmd"
        Set-Content -Path $cmdWrapper -Value "@echo off`r`nnode `"$cliJs`" %*"
    }

    $env:Path = "$binDir;$($env:Path)"
    Write-Host "  gws installed at $binDir\gws.cmd"
}

# Install gws-auth plugin.
function Install-GwsAuth {
    Write-Host ":: Installing gws-auth..."

    $url = "https://github.com/planetarium/gws-auth/releases/download/v0.4.0/planetarium-gws-auth-0.4.0.tgz"
    $prefix = Join-Path (Get-Location) ".local"
    $binDir = Join-Path $prefix "bin"
    New-Item -ItemType Directory -Force -Path $prefix | Out-Null
    New-Item -ItemType Directory -Force -Path $binDir | Out-Null

    # Ensure npm roaming directory exists
    $npmRoaming = Join-Path $env:APPDATA "npm"
    if (-not (Test-Path $npmRoaming)) {
        New-Item -ItemType Directory -Force -Path $npmRoaming | Out-Null
    }

    npm install --prefix $prefix $url 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [warn] gws-auth install failed. Install manually: npm i -g $url"
        return
    }

    $cliJs = Join-Path $prefix "node_modules" "@planetarium" "gws-auth" "bin" "gws-auth.js"
    if (Test-Path $cliJs) {
        $cmdWrapper = Join-Path $binDir "gws-auth.cmd"
        Set-Content -Path $cmdWrapper -Value "@echo off`r`nnode `"$cliJs`" %*"
    }

    $env:Path = "$binDir;$($env:Path)"
    Write-Host "  gws-auth installed at $binDir\gws-auth.cmd"
}

# Install camp identity/knowledge/manifest/tests files from a tarball URL.
# Extracts into a temporary directory and copies only expected entries.
function Install-CampFiles {
    param(
        [Parameter(Mandatory)][string]$Url
    )

    $allowedEntries = @("identity", "knowledge", "tests", "scripts", "manifest.yaml")

    Write-Host ":: Installing camp files..."

    $tmpTar = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName() + ".tgz")
    $extractDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())

    try {
        Invoke-WebRequest -Uri $Url -OutFile $tmpTar -UseBasicParsing -ErrorAction Stop
        New-Item -ItemType Directory -Force -Path $extractDir | Out-Null

        # List archive contents and reject path traversal or absolute paths
        $listing = tar tzf $tmpTar 2>$null
        foreach ($entry in $listing) {
            if ($entry -match '(^[/\\]|\.\.)') {
                Write-Error "  [error] Archive contains unsafe paths, aborting."
                return
            }
        }

        # Extract only allowed top-level entries
        foreach ($entry in $allowedEntries) {
            tar xzf $tmpTar -C $extractDir $entry 2>$null
        }

        $copied = $false
        foreach ($entry in $allowedEntries) {
            $src = Join-Path $extractDir $entry
            if (-not (Test-Path $src)) { continue }

            # Reject symlinks (ReparsePoint)
            $symlinks = Get-ChildItem -Path $src -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.Attributes -band [System.IO.FileAttributes]::ReparsePoint }
            if ($symlinks) {
                Write-Error "  [error] Archive contains symlinks under: $entry"
                return
            }

            $dest = Join-Path (Get-Location) $entry
            if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
            Copy-Item -Recurse -Force $src $dest
            $copied = $true
        }

        if (-not $copied) {
            Write-Error "  [error] No expected camp files found in archive: $Url"
        }
    }
    finally {
        Remove-Item -Force $tmpTar -ErrorAction SilentlyContinue
        Remove-Item -Recurse -Force $extractDir -ErrorAction SilentlyContinue
    }
}

# Detect the current agent platform.
# Override with CAMPFORGE_PLATFORM env var.
function Detect-Platform {
    if ($env:CAMPFORGE_PLATFORM) {
        return $env:CAMPFORGE_PLATFORM
    }

    if ((Get-Command openclaw -ErrorAction SilentlyContinue) -or $env:OPENCLAW_WORKSPACE) {
        return "openclaw"
    }
    elseif ((Get-Command codex -ErrorAction SilentlyContinue) -or $env:CODEX_HOME) {
        return "codex"
    }
    elseif ((Get-Command claude -ErrorAction SilentlyContinue) -or (Test-Path ".claude\CLAUDE.md")) {
        return "claude-code"
    }
    else {
        return "claude-code"
    }
}

# Generate platform-specific adapter files.
function Generate-Adapters {
    $platform = Detect-Platform

    # Collect identity and knowledge file paths
    $files = @()
    if (Test-Path "identity") {
        $files += Get-ChildItem -Path "identity" -Filter "*.md" -File -ErrorAction SilentlyContinue |
            ForEach-Object { $_.FullName | Resolve-Path -Relative }
    }
    if (Test-Path "knowledge") {
        $files += Get-ChildItem -Path "knowledge" -Filter "*.md" -File -ErrorAction SilentlyContinue |
            ForEach-Object { $_.FullName | Resolve-Path -Relative }
        if (Test-Path "knowledge\decision-trees") {
            $files += Get-ChildItem -Path "knowledge\decision-trees" -Filter "*.md" -File -ErrorAction SilentlyContinue |
                ForEach-Object { $_.FullName | Resolve-Path -Relative }
        }
    }

    if ($files.Count -eq 0) { return }

    Write-Host ":: Generating $platform adapter..."

    switch ($platform) {
        "claude-code" { Invoke-AdapterClaudeCode -Files $files }
        "openclaw"    { Invoke-AdapterOpenClaw }
        "codex"       { Invoke-AdapterCodex }
        default       { Write-Host "  [warn] Unknown platform '$platform', skipping adapter generation." }
    }
}

# Write content to a unique staging file.
function Write-Staging {
    param([string]$Content)

    $script:StagingFile = ".campforge-context.md"
    if (Test-Path $script:StagingFile) {
        $script:StagingFile = ".campforge-context-$([System.IO.Path]::GetRandomFileName().Replace('.', '')).md"
    }
    Set-Content -Path $script:StagingFile -Value $Content -Encoding UTF8
}

# Claude Code: generate .claude/CLAUDE.md with @ references.
function Invoke-AdapterClaudeCode {
    param([string[]]$Files)

    $lines = @("# Camp Context", "")
    foreach ($f in $Files) {
        # Normalize to forward-slash relative paths
        $rel = $f -replace '\\', '/' -replace '^\.\/', ''
        $lines += "@$rel"
    }
    $content = $lines -join "`n"

    New-Item -ItemType Directory -Force -Path ".claude" | Out-Null
    if (Test-Path ".claude\CLAUDE.md") {
        Write-Staging -Content $content
        Write-Host ""
        Write-Host "  [action-required] Existing .claude\CLAUDE.md found."
        Write-Host "  Camp context has been written to $script:StagingFile"
        Write-Host "  Please merge the @ references from $script:StagingFile into .claude\CLAUDE.md,"
        Write-Host "  then delete $script:StagingFile."
    }
    else {
        Set-Content -Path ".claude\CLAUDE.md" -Value $content -Encoding UTF8
        Write-Host "  Created .claude\CLAUDE.md with $($Files.Count) @ references"
    }
}

# OpenClaw: auto-loads SOUL.md, IDENTITY.md, AGENTS.md from workspace root.
function Invoke-AdapterOpenClaw {
    # Guide: OpenClaw needs skills.load.extraDirs to discover .agents/skills/.
    if (Test-Path ".agents\skills") {
        $agentsSkillsAbs = (Resolve-Path ".agents\skills").Path
        $openclawConfig = Join-Path $env:USERPROFILE ".openclaw" "openclaw.json"
        Write-Host ""
        if ((Test-Path $openclawConfig) -and ((Get-Content $openclawConfig -Raw) -match [regex]::Escape($agentsSkillsAbs))) {
            Write-Host "  [info] OpenClaw skills path already present in ~\.openclaw\openclaw.json:"
            Write-Host ""
            Write-Host "    $agentsSkillsAbs"
            Write-Host ""
        }
        else {
            Write-Host "  [action-required] To let OpenClaw discover installed skills,"
            Write-Host "  update ~\.openclaw\openclaw.json so skills.load.extraDirs includes:"
            Write-Host ""
            Write-Host "    $agentsSkillsAbs"
            Write-Host ""
            Write-Host "  If ~\.openclaw\openclaw.json does not exist yet, create it."
            Write-Host "  If it already exists, merge/add this path under skills.load.extraDirs"
            Write-Host "  and do not replace your whole existing OpenClaw configuration."
            Write-Host ""
        }
    }

    # Copy identity files to workspace root
    foreach ($f in @("SOUL.md", "IDENTITY.md")) {
        $src = "identity\$f"
        if (-not (Test-Path $src)) { continue }
        if (Test-Path $f) {
            Add-Content -Path $f -Value "`n`n---`n`n"
            Get-Content $src | Add-Content -Path $f
            Write-Host "  Appended identity\$f -> $f"
        }
        else {
            Copy-Item $src $f
            Write-Host "  Copied identity\$f -> $f"
        }
    }

    # AGENTS.md gets identity + knowledge merged
    $agentsContent = ""
    if (Test-Path "identity\AGENTS.md") {
        $agentsContent = Get-Content "identity\AGENTS.md" -Raw
    }

    $knowledgeContent = ""
    $knowledgeFiles = @()
    if (Test-Path "knowledge") {
        $knowledgeFiles += Get-ChildItem -Path "knowledge" -Filter "*.md" -File -ErrorAction SilentlyContinue
    }
    if (Test-Path "knowledge\decision-trees") {
        $knowledgeFiles += Get-ChildItem -Path "knowledge\decision-trees" -Filter "*.md" -File -ErrorAction SilentlyContinue
    }
    foreach ($kf in $knowledgeFiles) {
        $knowledgeContent += (Get-Content $kf.FullName -Raw) + "`n`n"
    }

    if ($knowledgeContent) {
        if ($agentsContent) {
            $agentsContent += "`n`n---`n# Knowledge Reference`n`n$knowledgeContent"
        }
        else {
            $agentsContent = "# Knowledge Reference`n`n$knowledgeContent"
        }
    }

    if ($agentsContent) {
        if (Test-Path "AGENTS.md") {
            Add-Content -Path "AGENTS.md" -Value "`n`n---`n`n"
            Add-Content -Path "AGENTS.md" -Value $agentsContent
            Write-Host "  Appended identity + knowledge -> AGENTS.md"
        }
        else {
            Set-Content -Path "AGENTS.md" -Value $agentsContent -Encoding UTF8
            Write-Host "  Created AGENTS.md with identity + knowledge"
        }
    }
}

# Codex: concatenate identity + knowledge into a root AGENTS.md.
function Invoke-AdapterCodex {
    $maxBytes = if ($env:CODEX_PROJECT_DOC_MAX_BYTES) { [int]$env:CODEX_PROJECT_DOC_MAX_BYTES } else { 32768 }

    $contentParts = @()
    foreach ($f in @("identity\SOUL.md", "identity\IDENTITY.md", "identity\AGENTS.md")) {
        if (Test-Path $f) {
            $contentParts += (Get-Content $f -Raw)
            $contentParts += "`n---`n"
        }
    }

    $knowledgeFiles = @()
    if (Test-Path "knowledge") {
        $knowledgeFiles += Get-ChildItem -Path "knowledge" -Filter "*.md" -File -ErrorAction SilentlyContinue
    }
    if (Test-Path "knowledge\decision-trees") {
        $knowledgeFiles += Get-ChildItem -Path "knowledge\decision-trees" -Filter "*.md" -File -ErrorAction SilentlyContinue
    }
    foreach ($kf in $knowledgeFiles) {
        $contentParts += (Get-Content $kf.FullName -Raw)
        $contentParts += ""
    }

    $content = $contentParts -join "`n"

    if (Test-Path "AGENTS.md") {
        Write-Staging -Content $content
        Write-Host ""
        Write-Host "  [action-required] Existing AGENTS.md found."
        Write-Host "  Camp context has been written to $script:StagingFile"
        Write-Host "  Please merge the content from $script:StagingFile into AGENTS.md"
        Write-Host "  (keep total size under ${maxBytes}B for Codex),"
        Write-Host "  then delete $script:StagingFile."
    }
    else {
        Set-Content -Path "AGENTS.md" -Value $content -Encoding UTF8
        $size = (Get-Item "AGENTS.md").Length
        if ($size -gt $maxBytes) {
            Write-Host "  [warn] AGENTS.md (${size}B) exceeds ${maxBytes}B limit, truncating on line boundaries."
            $lines = Get-Content "AGENTS.md"
            $truncated = @()
            $truncatedSize = 0
            foreach ($line in $lines) {
                $lineBytes = [System.Text.Encoding]::UTF8.GetByteCount($line + "`n")
                if (($truncatedSize + $lineBytes) -le $maxBytes) {
                    $truncated += $line
                    $truncatedSize += $lineBytes
                }
                else { break }
            }
            Set-Content -Path "AGENTS.md" -Value ($truncated -join "`n") -Encoding UTF8
        }
        $finalSize = (Get-Item "AGENTS.md").Length
        Write-Host "  Created AGENTS.md (${finalSize}B)"
    }
}
