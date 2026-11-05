#!/usr/bin/env bash
set -euo pipefail

# Firecrawl Extension Installer for Codex SEO
# Wraps everything in main() to prevent partial execution on network failure

main() {
    SKILL_DIR="${CODEX_HOME:-${HOME}/.codex}/skills/seo-firecrawl"
    AGENT_DIR="${CODEX_HOME:-${HOME}/.codex}/agents"
    SEO_SKILL_DIR="${CODEX_HOME:-${HOME}/.codex}/skills/seo"
    # MCP servers live in ~/.codex/config.toml (the file `claude mcp add` writes).
    # NOT ~/.codex/config.toml - `mcpServers` is not a key Claude Code reads
    # there, so entries written to settings.json silently never load.
    MCP_CONFIG_FILE="${CODEX_HOME:-${HOME}/.codex}/config.toml"

    echo "════════════════════════════════════════"
    echo "║   Firecrawl Extension - Installer    ║"
    echo "║   For Codex SEO                     ║"
    echo "════════════════════════════════════════"
    echo ""

    # Check prerequisites
    if [ ! -d "${SEO_SKILL_DIR}" ]; then
        echo "x Codex SEO is not installed."
        echo "  Install it first: curl -fsSL https://raw.githubusercontent.com/AgriciDaniel/claude-seo/main/install.sh | bash"
        exit 1
    fi
    echo "v Codex SEO detected"

    if ! command -v node >/dev/null 2>&1; then
        echo "x Node.js is required but not installed."
        echo "  Install Node.js 20+: https://nodejs.org/"
        exit 1
    fi

    NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
    if [ "${NODE_VERSION}" -lt 20 ]; then
        echo "x Node.js 20+ required (found v${NODE_VERSION})."
        echo "  Update: https://nodejs.org/"
        exit 1
    fi
    echo "v Node.js v$(node -v | sed 's/v//') detected"

    if ! command -v npx >/dev/null 2>&1; then
        echo "x npx is required but not found (comes with npm)."
        exit 1
    fi
    echo "v npx detected"

    # Prompt for credentials
    echo ""
    echo "Firecrawl API key required."
    echo "Sign up at: https://www.firecrawl.dev/app/sign-up"
    echo "Free tier: 500 credits/month"
    echo ""

    read -rsp "Firecrawl API key: " FIRECRAWL_API_KEY
    echo ""
    if [ -z "${FIRECRAWL_API_KEY}" ]; then
        echo "x API key cannot be empty."
        exit 1
    fi

    # Determine script directory (works for both ./install.sh and curl|bash)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Check if running from repo or standalone
    if [ -f "${SCRIPT_DIR}/skills/seo-firecrawl/SKILL.md" ]; then
        SOURCE_DIR="${SCRIPT_DIR}"
    elif [ -f "${SCRIPT_DIR}/extensions/firecrawl/skills/seo-firecrawl/SKILL.md" ]; then
        SOURCE_DIR="${SCRIPT_DIR}/extensions/firecrawl"
    else
        echo "x Cannot find extension source files."
        echo "  Run this script from the codex-seo repo: ./extensions/firecrawl/install.sh"
        exit 1
    fi

    # Install skill
    echo ""
    echo "-> Installing Firecrawl skill..."
    mkdir -p "${SKILL_DIR}"
    cp "${SOURCE_DIR}/skills/seo-firecrawl/SKILL.md" "${SKILL_DIR}/SKILL.md"

    # Merge MCP config into ~/.codex/config.toml
    echo "-> Configuring MCP server..."

    # Credentials travel in the environment (never argv, never interpolated into the source string)
    # and the settings file is written atomically with 0600 permissions.
    CODEX_SEO_SECRET="${FIRECRAWL_API_KEY}" python3 - "${MCP_CONFIG_FILE}" <<'PY'
import os, re, sys, tempfile
path, api_key = sys.argv[1], os.environ["CODEX_SEO_SECRET"]
SERVER = "firecrawl-mcp"

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

block = '[mcp_servers."%s"]\ncommand = "npx"\nargs = ["-y", "firecrawl-mcp@3.11.0"]\n\n[mcp_servers."%s".env]\nFIRECRAWL_API_KEY = "%s"\n' % (SERVER, SERVER, _esc(api_key))
_write(path, _drop(_read(path), SERVER) + block)
print("Configured MCP server firecrawl-mcp in Codex config.toml")
PY
    if [ $? -ne 0 ]; then
        echo "  Warning: Could not auto-configure MCP server."
        echo "  Add the firecrawl-mcp server manually to ~/.codex/config.toml"
        echo "  See: extensions/firecrawl/docs/FIRECRAWL-SETUP.md"
    fi

    # Pre-warm npm package without starting the MCP server binary.
    echo "-> Pre-downloading firecrawl-mcp..."
    npx --yes --package=firecrawl-mcp@3.11.0 -- node -e "" >/dev/null 2>&1 || true

    echo ""
    echo "v Firecrawl extension installed successfully!"
    echo ""
    echo "Usage:"
    echo "  1. Restart Codex, then run the skill"
    echo "  2. Run commands:"
    echo "     /seo firecrawl crawl https://example.com"
    echo "     /seo firecrawl map https://example.com"
    echo "     /seo firecrawl scrape https://example.com/page"
    echo "     /seo firecrawl search \"query\" https://example.com"
    echo ""
    echo "Documentation: extensions/firecrawl/README.md"
    echo "To uninstall: ./extensions/firecrawl/uninstall.sh"
}

main "$@"
