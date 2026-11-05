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
$py = @"
import os, re, sys, tempfile
path = sys.argv[1]
idx_loc = sys.argv[2] if len(sys.argv) > 2 else ""
bing = os.environ.get("CODEX_SEO_SECRET", "")
idx_key = os.environ.get("CODEX_SEO_INDEXNOW_KEY", "")

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
    pattern = re.compile(r'(?ms)^\[codex_seo\.bing\]\n.*?(?=^\[|\Z)')
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

lines = ["[codex_seo.bing]"]
if bing:
    lines.append('BING_WEBMASTER_API_KEY = "%s"' % _esc(bing))
if idx_key:
    lines.append('INDEXNOW_KEY = "%s"' % _esc(idx_key))
if idx_loc:
    lines.append('INDEXNOW_KEY_LOCATION = "%s"' % _esc(idx_loc))
block = "\n".join(lines) + "\n"
_write(path, _drop(_read(path)) + block)
print("Configured codex_seo.bing in Codex config.toml")
"@
$env:CODEX_SEO_SECRET = $BingPlain
$env:CODEX_SEO_INDEXNOW_KEY = $IdxKey
try {
    $py | python - $SettingsJson $IdxLoc
    # A native command's non-zero exit does not throw, even with Stop.
    if ($LASTEXITCODE -ne 0) { throw "Nothing was saved (python exited $LASTEXITCODE). See the message above." }
} finally { Remove-Item Env:CODEX_SEO_SECRET -ErrorAction SilentlyContinue; Remove-Item Env:CODEX_SEO_INDEXNOW_KEY -ErrorAction SilentlyContinue }
Write-Host "Done."
