# Codex SEO - Ahrefs extension installer (Windows / PowerShell).
# Mirrors extensions/ahrefs/install.sh.
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Test-Cmd($name) {
    $null = Get-Command $name -ErrorAction SilentlyContinue
    return $?
}

if (-not (Test-Cmd npx)) { throw "Node 18+ / npx is required." }

$SkillDir = Join-Path $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }) "skills"
# MCP servers live in ~/.codex/config.toml (the file `claude mcp add` writes).
# NOT ~/.codex/config.toml - `mcpServers` is not a key Claude Code reads
# there, so entries written to settings.json silently never load.
$McpConfigJson = Join-Path $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }) "config.toml"

if (-not (Test-Path (Join-Path $SkillDir "seo"))) {
    throw "codex-seo base plugin not installed."
}

$Token = Read-Host "Ahrefs API token" -AsSecureString
$Plain = [System.Net.NetworkCredential]::new("", $Token).Password
if (-not $Plain) { throw "No token provided." }

$SourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillTarget = Join-Path $SkillDir "seo-ahrefs"
New-Item -ItemType Directory -Path $SkillTarget -Force | Out-Null
Copy-Item -Path (Join-Path $SourceDir "skills/seo-ahrefs/SKILL.md") `
          -Destination (Join-Path $SkillTarget "SKILL.md") -Force
Write-Host "[OK] Installed skill: $SkillTarget"

# Pre-warm.
& npx --yes --package=@ahrefs/mcp@0.0.11 mcp --help *> $null

# Merge ~/.codex/config.toml through the shared TOML editor.
if (-not (Get-Command python -ErrorAction SilentlyContinue)) { throw "Python 3 required." }
$Helper = Join-Path (Split-Path -Parent (Split-Path -Parent $SourceDir)) "scripts\codex_config.py"
if (-not (Test-Path $Helper)) { throw "codex_config.py not found at $Helper" }
$env:CODEX_SEO_SECRET = $Plain
try {
    & python $Helper upsert-mcp --path $McpConfigJson --server ahrefs --command npx --arg=--yes --arg=--package=@ahrefs/mcp@0.0.11 --arg=mcp --env-from AHREFS_API_TOKEN=CODEX_SEO_SECRET
    if ($LASTEXITCODE -ne 0) { throw "Nothing was saved (python exited $LASTEXITCODE). See the message above." }
} finally {
    Remove-Item Env:CODEX_SEO_SECRET -ErrorAction SilentlyContinue
}
Write-Host "Configured mcp_servers.ahrefs in $McpConfigJson"

Write-Host ""
Write-Host "Done. Open a new Claude Code session and run /seo ahrefs metrics <url>."
