# Codex SEO - SE Ranking extension installer (Windows / PowerShell).
$ErrorActionPreference = "Stop"

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    throw "Python 3 is required."
}

$SkillDir = Join-Path $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }) "skills"
$SettingsJson = Join-Path $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }) "config.toml"

if (-not (Test-Path (Join-Path $SkillDir "seo"))) {
    throw "codex-seo base plugin not installed."
}

$Key = Read-Host "SE Ranking API key" -AsSecureString
$Plain = [System.Net.NetworkCredential]::new("", $Key).Password
if (-not $Plain) { throw "No key provided." }

$SourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillTarget = Join-Path $SkillDir "seo-seranking"
New-Item -ItemType Directory -Path $SkillTarget -Force | Out-Null
Copy-Item -Path (Join-Path $SourceDir "skills/seo-seranking/SKILL.md") `
          -Destination (Join-Path $SkillTarget "SKILL.md") -Force

$pyScript = @"
import os, re, sys, tempfile
path, key = sys.argv[1], os.environ["CODEX_SEO_SECRET"]

def _esc(value):
    return str(value).replace("\\", "\\\\").replace('"', '\\"').replace("\r", "\\r").replace("\n", "\\n")

def _read(target):
    if not os.path.exists(target) or os.path.getsize(target) == 0:
        return ""
    text = open(target, encoding="utf-8").read()
    try:
        import tomllib
        tomllib.loads(text)
    except Exception:
        sys.exit("x " + target + " is not valid TOML. Nothing was changed; fix it and rerun.")
    return text

def _drop(text):
    pattern = re.compile(r'(?ms)^\[codex_seo\.seranking\]\n.*?(?=^\[|\Z)')
    return pattern.sub("", text).rstrip() + "\n"

def _write(target, text):
    directory = os.path.dirname(target) or "."
    os.makedirs(directory, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=directory, prefix=".config.", suffix=".toml")
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text if text.endswith("\n") else text + "\n")
        os.chmod(tmp, 0o600)
        os.replace(tmp, target)
    except Exception:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise

block = '[codex_seo.seranking]\nSERANKING_API_KEY = "%s"\n' % _esc(key)
_write(path, _drop(_read(path)) + block)
print("Configured codex_seo.seranking in Codex config.toml")
"@
$env:CODEX_SEO_SECRET = $Plain
try {
    $pyScript | python - $SettingsJson
    # A native command's non-zero exit does not throw, even with Stop.
    if ($LASTEXITCODE -ne 0) { throw "Nothing was saved (python exited $LASTEXITCODE). See the message above." }
} finally { Remove-Item Env:CODEX_SEO_SECRET -ErrorAction SilentlyContinue }
Write-Host "Done. Try: /seo seranking ai-visibility brandname"
