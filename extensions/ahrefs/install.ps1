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

# Merge ~/.codex/config.toml.
$settingsContent = if (Test-Path $McpConfigJson) { Get-Content $McpConfigJson -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
if (-not $settingsContent.mcpServers) { $settingsContent | Add-Member -NotePropertyName mcpServers -NotePropertyValue ([pscustomobject]@{}) -Force }
$settingsContent.mcpServers | Add-Member -NotePropertyName 'ahrefs' -NotePropertyValue @{
    command = 'npx'
    args = @('--yes', '--package=@ahrefs/mcp@0.0.11', 'mcp')
    env = @{ AHREFS_API_TOKEN = $Plain }
} -Force
# Write atomically: stage to a temp file in the same directory, then swap
# it into place, so a crash mid-write never leaves ~/.codex/config.toml truncated
# or half-written (it is shared with Claude Code and other installers).
# -Depth 100 (not the ConvertTo-Json default of 2) so an existing
# ~/.codex/config.toml with deeply nested config round-trips intact.
$TempConfigJson = Join-Path (Split-Path -Parent $McpConfigJson) ".config.toml.$([guid]::NewGuid().ToString('N')).tmp"
$jsonText = $settingsContent | ConvertTo-Json -Depth 100
# Write without a byte-order mark: on Windows PowerShell 5.1, Set-Content -Encoding UTF8
# emits a BOM and Node's JSON.parse rejects it, which would make ~/.codex/config.toml unreadable.
[System.IO.File]::WriteAllText($TempConfigJson, $jsonText, (New-Object System.Text.UTF8Encoding $false))
Move-Item -Path $TempConfigJson -Destination $McpConfigJson -Force
Write-Host "Wrote mcpServers.ahrefs to $McpConfigJson"

Write-Host ""
Write-Host "Done. Open a new Claude Code session and run /seo ahrefs metrics <url>."
