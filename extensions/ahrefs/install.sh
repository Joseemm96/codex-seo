#!/usr/bin/env bash
# Codex SEO: Ahrefs extension installer.
#
# Wires the official @ahrefs/mcp server into ~/.codex/config.toml and
# copies the seo-ahrefs mirror skill into ~/.codex/skills/.
#
# Prereq: an Ahrefs API token. Get one at https://ahrefs.com/api.
set -euo pipefail

main() {
    SKILL_DIR="${CODEX_HOME:-${HOME}/.codex}/skills"
    # MCP servers live in ~/.codex/config.toml (the file `claude mcp add` writes).
    # NOT ~/.codex/config.toml - `mcpServers` is not a key Claude Code reads
    # there, so entries written to settings.json silently never load.
    MCP_CONFIG_JSON="${CODEX_HOME:-${HOME}/.codex}/config.toml"

    echo "════════════════════════════════════════"
    echo "║   Codex SEO: Ahrefs extension       ║"
    echo "════════════════════════════════════════"

    command -v python3 >/dev/null 2>&1 || {
        echo "✗ Python 3 required."; exit 1;
    }
    command -v npx >/dev/null 2>&1 || {
        echo "✗ Node 18+ / npx required."; exit 1;
    }

    if [ ! -d "${SKILL_DIR}/seo" ]; then
        echo "✗ codex-seo base plugin not installed."
        echo "  Install it first: curl -fsSL https://raw.githubusercontent.com/AgriciDaniel/claude-seo/main/install.sh | bash"
        exit 1
    fi

    # Locate this script's directory so the call works for both
    # `./install.sh` and `curl | bash` invocations.
    SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd)"

    read -rsp "Ahrefs API token: " AHREFS_TOKEN
    echo
    if [ -z "${AHREFS_TOKEN}" ]; then
        echo "✗ No token provided."; exit 1;
    fi

    # Pre-warm the package so the first MCP invocation isn't slow.
    echo "→ Pre-warming @ahrefs/mcp..."
    npx --yes --package=@ahrefs/mcp@0.0.11 mcp --help >/dev/null 2>&1 || true

    mkdir -p "${SKILL_DIR}/seo-ahrefs"
    cp "${SOURCE_DIR}/skills/seo-ahrefs/SKILL.md" "${SKILL_DIR}/seo-ahrefs/SKILL.md"
    echo "✓ Installed skill: ${SKILL_DIR}/seo-ahrefs/SKILL.md"

    # Merge MCP config into ~/.codex/config.toml atomically.
    mkdir -p "$(dirname "${MCP_CONFIG_JSON}")"
    CODEX_SEO_SECRET="${AHREFS_TOKEN}" python3 - "${MCP_CONFIG_JSON}" <<'PY'
import os, re, sys, tempfile
path, token = sys.argv[1], os.environ["CODEX_SEO_SECRET"]
SERVER = "ahrefs"

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

def _drop(text, server):
    pattern = re.compile('(?ms)^\\[mcp_servers\\."' + re.escape(server) + '"(?:\\.[^\\]]*)?\\]\\n.*?(?=^\\[|\\Z)')
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

block = '[mcp_servers."ahrefs"]\ncommand = "npx"\nargs = ["--yes", "--package=@ahrefs/mcp@0.0.11", "mcp"]\n\n[mcp_servers."ahrefs".env]\nAHREFS_API_TOKEN = "%s"\n' % _esc(token)
_write(path, _drop(_read(path), SERVER) + block)
print("Configured MCP server ahrefs in Codex config.toml")
PY

    echo
    echo "Done. Open a new Claude Code session and run:"
    echo "  /seo ahrefs metrics https://example.com"
    echo
    echo "Full docs: extensions/ahrefs/docs/AHREFS-SETUP.md"
}

main "$@"
