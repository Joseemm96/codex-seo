#!/usr/bin/env bash
# Codex SEO: Profound (LLM citation tracker) extension installer.
#
# Profound tracks brand citation rates across major LLMs and exposes
# them as structured time-series. Pairs with seo-seranking (which
# samples mention rates) for triangulated AI visibility data.
set -euo pipefail

main() {
    SKILL_DIR="${CODEX_HOME:-${HOME}/.codex}/skills"
    SETTINGS_JSON="${CODEX_HOME:-${HOME}/.codex}/config.toml"

    echo "════════════════════════════════════════"
    echo "║   Codex SEO: Profound extension     ║"
    echo "════════════════════════════════════════"

    command -v python3 >/dev/null 2>&1 || { echo "✗ Python 3 required."; exit 1; }
    [ ! -d "${SKILL_DIR}/seo" ] && { echo "✗ codex-seo base not installed."; exit 1; }

    SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd)"

    read -rsp "Profound API key: " PROFOUND_KEY
    echo
    [ -z "${PROFOUND_KEY}" ] && { echo "✗ No key provided."; exit 1; }

    mkdir -p "${SKILL_DIR}/seo-profound"
    cp "${SOURCE_DIR}/skills/seo-profound/SKILL.md" "${SKILL_DIR}/seo-profound/SKILL.md"

    CODEX_SEO_SECRET="${PROFOUND_KEY}" python3 - "${SETTINGS_JSON}" <<'PY'
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
PY

    echo "Done. Try: /seo profound citations brandname"
}
main "$@"
