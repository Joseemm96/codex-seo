# Firecrawl Extension Uninstaller for Codex SEO (Windows)
$ErrorActionPreference = 'Stop'

Write-Host "Removing Firecrawl extension..." -ForegroundColor Yellow

$SkillDir = "$(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' })\skills\seo-firecrawl"
$McpConfigFile = "$(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' })\config.toml"

if (Test-Path $SkillDir) {
    Remove-Item -Recurse -Force $SkillDir
    Write-Host "v Removed skill files" -ForegroundColor Green
}

if (Test-Path $McpConfigFile) {
    $settings = Get-Content $McpConfigFile -Raw | ConvertFrom-Json
    if ($settings.mcpServers.'firecrawl-mcp') {
        $settings.mcpServers.PSObject.Properties.Remove('firecrawl-mcp')
        # Write atomically: stage to a temp file in the same directory, then
        # swap it into place, so a crash mid-write never leaves
        # ~/.codex/config.toml truncated or half-written (it is shared with
        # Claude Code and other installers).
        # -Depth 100 (not the ConvertTo-Json default of 2, or the previous
        # 10) so an existing ~/.codex/config.toml with deeply nested config
        # round-trips intact.
        $TempConfigFile = Join-Path (Split-Path -Parent $McpConfigFile) ".config.toml.$([guid]::NewGuid().ToString('N')).tmp"
        $jsonText = $settings | ConvertTo-Json -Depth 100
# Write without a byte-order mark: on Windows PowerShell 5.1, Set-Content -Encoding UTF8
# emits a BOM and Node's JSON.parse rejects it, which would make ~/.codex/config.toml unreadable.
[System.IO.File]::WriteAllText($TempConfigFile, $jsonText, (New-Object System.Text.UTF8Encoding $false))
        Move-Item -Path $TempConfigFile -Destination $McpConfigFile -Force
        Write-Host "v Removed MCP server from ~/.codex/config.toml" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "v Firecrawl extension uninstalled." -ForegroundColor Green
Write-Host "  Core Codex SEO skills are unchanged."
