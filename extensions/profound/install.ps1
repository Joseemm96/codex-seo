$ErrorActionPreference = "Stop"
if (-not (Get-Command python -ErrorAction SilentlyContinue)) { throw "Python 3 required" }
$SkillDir = Join-Path $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }) "skills"
$SettingsJson = Join-Path $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }) "config.toml"
if (-not (Test-Path (Join-Path $SkillDir "seo"))) { throw "codex-seo not installed" }
$Key = Read-Host "Profound API key" -AsSecureString
$Plain = [System.Net.NetworkCredential]::new("", $Key).Password
$SourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillTarget = Join-Path $SkillDir "seo-profound"
New-Item -ItemType Directory -Path $SkillTarget -Force | Out-Null
Copy-Item (Join-Path $SourceDir "skills/seo-profound/SKILL.md") `
          (Join-Path $SkillTarget "SKILL.md") -Force
$py = @"
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
    pattern = re.compile(r'(?ms)^\[codex_seo\.profound\]\n.*?(?=^\[|\Z)')
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

block = '[codex_seo.profound]\nPROFOUND_API_KEY = "%s"\n' % _esc(key)
_write(path, _drop(_read(path)) + block)
print("Configured codex_seo.profound in Codex config.toml")
"@
$env:CODEX_SEO_SECRET = $Plain
try {
    $py | python - $SettingsJson
    # A native command's non-zero exit does not throw, even with Stop.
    if ($LASTEXITCODE -ne 0) { throw "Nothing was saved (python exited $LASTEXITCODE). See the message above." }
} finally { Remove-Item Env:CODEX_SEO_SECRET -ErrorAction SilentlyContinue }
Write-Host "Done."
