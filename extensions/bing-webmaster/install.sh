#!/usr/bin/env bash
# Codex SEO: Bing Webmaster + IndexNow extension installer.
#
# Wires the existing scripts/bing_webmaster.py and indexnow_submit.py into
# a discoverable seo-bing skill and stores the Bing Webmaster Tools API
# key + IndexNow host key in ~/.codex/config.toml.
#
# Microsoft Copilot citations are fed by the Bing index, making this the
# canonical extension for "AI search visibility outside Google".
set -euo pipefail

main() {
    SKILL_DIR="${CODEX_HOME:-${HOME}/.codex}/skills"
    SETTINGS_JSON="${CODEX_HOME:-${HOME}/.codex}/config.toml"

    echo "════════════════════════════════════════"
    echo "║ Codex SEO: Bing Webmaster + IndexNow ║"
    echo "════════════════════════════════════════"

    command -v python3 >/dev/null 2>&1 || { echo "✗ Python 3 required."; exit 1; }
    [ ! -d "${SKILL_DIR}/seo" ] && { echo "✗ codex-seo base not installed."; exit 1; }

    SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd)"

    read -rsp "Bing Webmaster Tools API key (https://www.bing.com/webmasters/api): " BING_KEY
    echo
    read -rp  "IndexNow host key (32+ chars, you'll publish this at /<key>.txt): " INDEXNOW_KEY
    read -rp  "IndexNow keyLocation URL (https://example.com/<key>.txt): " INDEXNOW_LOC

    [ -z "${BING_KEY}" ] && [ -z "${INDEXNOW_KEY}" ] && {
        echo "✗ Provide at least one of: Bing API key, IndexNow key."; exit 1;
    }

    mkdir -p "${SKILL_DIR}/seo-bing"
    cp "${SOURCE_DIR}/skills/seo-bing/SKILL.md" "${SKILL_DIR}/seo-bing/SKILL.md"

    CODEX_SEO_SECRET="${BING_KEY}" CODEX_SEO_INDEXNOW_KEY="${INDEXNOW_KEY}" python3 - "${SETTINGS_JSON}" "${INDEXNOW_LOC}" <<'PY'
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
PY

    echo
    echo "Done. Verify your IndexNow key is published (manual install path shown;"
    echo "plugin installs use \"\${CODEX_PLUGIN_ROOT}/scripts/codex-seo\" instead):"
    echo "  \"\$HOME/.codex/skills/seo/scripts/codex-seo\" run indexnow_submit.py --host example.com \\"
    echo "    --key \$INDEXNOW_KEY --key-location \$INDEXNOW_KEY_LOCATION --verify-only"
}
main "$@"
