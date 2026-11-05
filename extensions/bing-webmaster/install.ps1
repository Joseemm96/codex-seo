$ErrorActionPreference = "Stop"
if (-not (Get-Command python -ErrorAction SilentlyContinue)) { throw "Python 3 required" }
$SkillDir = Join-Path $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }) "skills"
$SettingsJson = Join-Path $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }) "config.toml"
if (-not (Test-Path (Join-Path $SkillDir "seo"))) { throw "codex-seo not installed" }
$BingKey = (Read-Host "Bing Webmaster Tools API key" -AsSecureString)
$IdxKey  = Read-Host "IndexNow host key (32+ chars)"
$IdxLoc  = Read-Host "IndexNow keyLocation URL"
$BingPlain = [System.Net.NetworkCredential]::new("", $BingKey).Password
if (-not $BingPlain -and -not $IdxKey) { throw "Provide at least one of: Bing API key, IndexNow key." }
$SourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillTarget = Join-Path $SkillDir "seo-bing"
New-Item -ItemType Directory -Path $SkillTarget -Force | Out-Null
Copy-Item (Join-Path $SourceDir "skills/seo-bing/SKILL.md") (Join-Path $SkillTarget "SKILL.md") -Force
$Helper = Join-Path (Split-Path -Parent (Split-Path -Parent $SourceDir)) "scripts\codex_config.py"
if (-not (Test-Path $Helper)) { throw "codex_config.py not found at $Helper" }
$env:CODEX_SEO_SECRET = $BingPlain
$env:CODEX_SEO_INDEXNOW_KEY = $IdxKey
$env:CODEX_SEO_INDEXNOW_LOCATION = $IdxLoc
try {
    & python $Helper store-bing --path $SettingsJson
    # A native command's non-zero exit does not throw, even with Stop.
    if ($LASTEXITCODE -ne 0) { throw "Nothing was saved (python exited $LASTEXITCODE). See the message above." }
} finally {
    Remove-Item Env:CODEX_SEO_SECRET -ErrorAction SilentlyContinue
    Remove-Item Env:CODEX_SEO_INDEXNOW_KEY -ErrorAction SilentlyContinue
    Remove-Item Env:CODEX_SEO_INDEXNOW_LOCATION -ErrorAction SilentlyContinue
}
Write-Host "Done."
