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
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        throw "Python 3 required to remove firecrawl-mcp from config.toml"
    }
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $Helper = Join-Path (Split-Path -Parent (Split-Path -Parent $ScriptDir)) "scripts\codex_config.py"
    if (-not (Test-Path $Helper)) { throw "codex_config.py not found at $Helper" }
    & python $Helper remove-mcp --path $McpConfigFile --server firecrawl-mcp
    if ($LASTEXITCODE -ne 0) { throw "Could not remove firecrawl-mcp from $McpConfigFile" }
    Write-Host "v Removed MCP server from ~/.codex/config.toml" -ForegroundColor Green
}

Write-Host ""
Write-Host "v Firecrawl extension uninstalled." -ForegroundColor Green
Write-Host "  Core Codex SEO skills are unchanged."
