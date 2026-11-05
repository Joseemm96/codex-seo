# Install the schema and SEO checks as this repository's Git pre-commit hook.
# Codex has no pre-commit plugin event. Git for Windows runs the hook with sh.
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$Runner = Join-Path $Root "hooks\pre-commit-schema-check.sh"
$Marker = "# codex-seo-schema-hook"
if (-not (Test-Path $Runner)) { throw "Missing $Runner" }

$HooksRel = & git -C $Root rev-parse --git-path hooks
if ($LASTEXITCODE -ne 0) {
    throw "$Root is not a Git checkout. This hook is for a local clone, not a plugin install."
}
if (-not [System.IO.Path]::IsPathRooted($HooksRel)) {
    $HooksDir = Join-Path $Root $HooksRel
} else {
    $HooksDir = $HooksRel
}
New-Item -ItemType Directory -Force -Path $HooksDir | Out-Null
$Target = Join-Path $HooksDir "pre-commit"
if (Test-Path $Target) {
    $existing = Get-Content -Path $Target -Raw
    if ($existing -notmatch "codex-seo-schema-hook") {
        throw "Refusing to replace existing $Target. Move it aside and rerun."
    }
}

$escaped = $Runner.Replace("'", "'\''")
$lines = @(
    "#!/usr/bin/env bash",
    $Marker,
    "exec '$escaped' `"`$@`""
)
$payload = ($lines -join "`n") + "`n"
[System.IO.File]::WriteAllText($Target, $payload)
Write-Host "Installed Git pre-commit hook: $Target"
