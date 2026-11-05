# Remove the Bing Webmaster extension and the credentials its tools read.
$ErrorActionPreference = "Stop"
if (-not (Get-Command python -ErrorAction SilentlyContinue)) { throw "Python 3 required" }

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Helper = Join-Path (Split-Path -Parent (Split-Path -Parent $ScriptDir)) "scripts\codex_config.py"
$CodexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }
$SkillDir = Join-Path $CodexHome "skills\seo-bing"
$Settings = Join-Path $CodexHome "config.toml"

if (Test-Path $SkillDir) {
    Remove-Item -Recurse -Force $SkillDir
    Write-Host "Removed $SkillDir"
}
if (-not (Test-Path $Helper)) { throw "codex_config.py not found at $Helper" }
& python $Helper remove-bing --path $Settings
if ($LASTEXITCODE -ne 0) { throw "Bing credentials were not removed" }
Write-Host "Removed Bing and IndexNow credentials."
