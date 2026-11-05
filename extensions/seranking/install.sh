#!/usr/bin/env bash
# Codex SEO: SE Ranking extension installer.
#
# SE Ranking's strength for v2: AI Share-of-Voice tracking across
# ChatGPT, Gemini, Perplexity, AI Overviews, and AI Mode. The gap
# analysis ranks this as the highest-impact new extension because no
# other vendor offers a single MCP/API surface for all 5 AI platforms.
#
# Prereq: SE Ranking API key. Get one at https://seranking.com/api
set -euo pipefail

main() {
    SKILL_DIR="${CODEX_HOME:-${HOME}/.codex}/skills"
    SETTINGS_JSON="${CODEX_HOME:-${HOME}/.codex}/config.toml"

    echo "════════════════════════════════════════"
    echo "║ Codex SEO: SE Ranking extension     ║"
    echo "════════════════════════════════════════"

    command -v python3 >/dev/null 2>&1 || { echo "✗ Python 3 required."; exit 1; }

    if [ ! -d "${SKILL_DIR}/seo" ]; then
        echo "✗ codex-seo base plugin not installed."
        exit 1
    fi

    SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd)"

    read -rsp "SE Ranking API key: " SR_KEY
    echo
    [ -z "${SR_KEY}" ] && { echo "✗ No key provided."; exit 1; }

    mkdir -p "${SKILL_DIR}/seo-seranking"
    cp "${SOURCE_DIR}/skills/seo-seranking/SKILL.md" "${SKILL_DIR}/seo-seranking/SKILL.md"
    echo "✓ Installed skill: ${SKILL_DIR}/seo-seranking/SKILL.md"

    mkdir -p "$(dirname "${SETTINGS_JSON}")"
    CODEX_SEO_SECRET="${SR_KEY}" python3 - "${SETTINGS_JSON}" <<'PY'
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
PY

    echo
    echo "Done. Try: /seo seranking ai-visibility brandname"
    echo "Full docs: extensions/seranking/docs/SERANKING-SETUP.md"
}

main "$@"
