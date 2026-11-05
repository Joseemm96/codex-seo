# DataForSEO Extension Uninstaller for Codex SEO (Windows)

$ErrorActionPreference = "Stop"

Write-Host "-> Uninstalling DataForSEO extension..." -ForegroundColor Yellow

# Remove skill
if (Test-Path "$(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' })\skills\seo-dataforseo") {
    Remove-Item -Recurse -Force "$(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' })\skills\seo-dataforseo"
}

# Remove agent
$agentFile = "$(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' })\agents\seo-dataforseo.toml"
if (Test-Path $agentFile) {
    Remove-Item -Force $agentFile
}

# Remove field config
$fieldConfig = "$(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' })\skills\seo\dataforseo-field-config.json"
if (Test-Path $fieldConfig) {
    Remove-Item -Force $fieldConfig
}

# Remove MCP server entry from ~/.codex/config.toml
$settingsFile = "$(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' })\config.toml"
if (Test-Path $settingsFile) {
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        throw "Python 3 required to remove dataforseo from config.toml"
    }
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $Helper = Join-Path (Split-Path -Parent (Split-Path -Parent $ScriptDir)) "scripts\codex_config.py"
    if (-not (Test-Path $Helper)) { throw "codex_config.py not found at $Helper" }
    & python $Helper remove-mcp --path $settingsFile --server dataforseo
    if ($LASTEXITCODE -ne 0) { throw "Could not remove dataforseo from $settingsFile" }
    Write-Host "  [OK] Removed dataforseo from ~/.codex/config.toml" -ForegroundColor Green
}

Write-Host "[OK] DataForSEO extension uninstalled." -ForegroundColor Green
