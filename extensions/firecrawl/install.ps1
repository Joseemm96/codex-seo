# Firecrawl Extension Installer for Codex SEO (Windows)
$ErrorActionPreference = 'Stop'

Write-Host "====================================" -ForegroundColor Cyan
Write-Host "  Firecrawl Extension - Installer" -ForegroundColor Cyan
Write-Host "  For Codex SEO" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

$SkillDir = "$(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' })\skills\seo-firecrawl"
$SeoSkillDir = "$(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' })\skills\seo"
# MCP servers live in ~/.codex/config.toml (the file `claude mcp add` writes).
# NOT ~/.codex/config.toml - `mcpServers` is not a key Claude Code reads
# there, so entries written to settings.json silently never load.
$McpConfigFile = "$(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' })\config.toml"

# Check prerequisites
if (-not (Test-Path $SeoSkillDir)) {
    Write-Host "x Codex SEO is not installed." -ForegroundColor Red
    Write-Host "  Install it first: irm https://raw.githubusercontent.com/AgriciDaniel/claude-seo/main/install.ps1 | iex"
    exit 1
}
Write-Host "v Codex SEO detected" -ForegroundColor Green

$nodeVersion = (node -v 2>$null) -replace 'v',''
if (-not $nodeVersion) {
    Write-Host "x Node.js is required but not installed." -ForegroundColor Red
    exit 1
}
$major = [int]($nodeVersion -split '\.')[0]
if ($major -lt 20) {
    Write-Host "x Node.js 20+ required (found v$nodeVersion)." -ForegroundColor Red
    exit 1
}
Write-Host "v Node.js v$nodeVersion detected" -ForegroundColor Green

# Prompt for API key
Write-Host ""
Write-Host "Firecrawl API key required." -ForegroundColor Yellow
Write-Host "Sign up at: https://www.firecrawl.dev/app/sign-up"
Write-Host "Free tier: 500 credits/month"
Write-Host ""

$apiKey = Read-Host "Firecrawl API key" -AsSecureString
$apiKeyPlain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($apiKey))
if ([string]::IsNullOrWhiteSpace($apiKeyPlain)) {
    Write-Host "x API key cannot be empty." -ForegroundColor Red
    exit 1
}

# Determine source directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SourceDir = $null
if (Test-Path "$ScriptDir\skills\seo-firecrawl\SKILL.md") {
    $SourceDir = $ScriptDir
} elseif (Test-Path "$ScriptDir\extensions\firecrawl\skills\seo-firecrawl\SKILL.md") {
    $SourceDir = "$ScriptDir\extensions\firecrawl"
} else {
    Write-Host "x Cannot find extension source files." -ForegroundColor Red
    exit 1
}

# Install skill
Write-Host ""
Write-Host "=> Installing Firecrawl skill..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $SkillDir | Out-Null
Copy-Item "$SourceDir\skills\seo-firecrawl\SKILL.md" "$SkillDir\SKILL.md" -Force

# Configure MCP server through the shared TOML editor. It replaces only
# firecrawl-mcp (quoted or bare headings) and validates the full document.
Write-Host "=> Configuring MCP server..." -ForegroundColor Yellow
if (-not (Get-Command python -ErrorAction SilentlyContinue)) { throw "Python 3 required" }
$Helper = Join-Path (Split-Path -Parent (Split-Path -Parent $SourceDir)) "scripts\codex_config.py"
if (-not (Test-Path $Helper)) { throw "codex_config.py not found at $Helper" }
$env:CODEX_SEO_SECRET = $apiKeyPlain
try {
    & python $Helper upsert-mcp --path $McpConfigFile --server firecrawl-mcp --command npx --arg=-y --arg=firecrawl-mcp@3.11.0 --env-from FIRECRAWL_API_KEY=CODEX_SEO_SECRET
    if ($LASTEXITCODE -ne 0) { throw "Nothing was saved (python exited $LASTEXITCODE). See the message above." }
} finally {
    Remove-Item Env:CODEX_SEO_SECRET -ErrorAction SilentlyContinue
}
Write-Host "  v MCP server configured" -ForegroundColor Green

# Pre-warm
Write-Host "=> Pre-downloading firecrawl-mcp..." -ForegroundColor Yellow
npx -y firecrawl-mcp@3.11.0 --help 2>$null | Out-Null

Write-Host ""
Write-Host "v Firecrawl extension installed!" -ForegroundColor Green
Write-Host ""
Write-Host "Usage:"
Write-Host "  /seo firecrawl crawl https://example.com"
Write-Host "  /seo firecrawl map https://example.com"
Write-Host "  /seo firecrawl scrape https://example.com/page"
