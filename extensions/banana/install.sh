#!/usr/bin/env bash
set -euo pipefail

# Banana Image Generation Extension Installer for Codex SEO
# Wraps everything in main() to prevent partial execution on network failure

main() {
    SKILL_DIR="${CODEX_HOME:-${HOME}/.codex}/skills/seo-image-gen"
    AGENT_DIR="${CODEX_HOME:-${HOME}/.codex}/agents"
    SEO_SKILL_DIR="${CODEX_HOME:-${HOME}/.codex}/skills/seo"
    # MCP servers live in ~/.codex/config.toml (the file `claude mcp add` writes).
    # NOT ~/.codex/config.toml - `mcpServers` is not a key Claude Code reads
    # there, so entries written to settings.json silently never load.
    MCP_CONFIG_FILE="${CODEX_HOME:-${HOME}/.codex}/config.toml"

    echo "════════════════════════════════════════"
    echo "║  Banana Image Gen - SEO Extension    ║"
    echo "║  For Codex SEO                      ║"
    echo "════════════════════════════════════════"
    echo ""

    # Check prerequisites
    if [ ! -d "${SEO_SKILL_DIR}" ]; then
        echo "✗ Codex SEO is not installed."
        echo "  Install it first: curl -fsSL https://raw.githubusercontent.com/AgriciDaniel/claude-seo/main/install.sh | bash"
        exit 1
    fi
    echo "✓ Codex SEO detected"

    if ! command -v node >/dev/null 2>&1; then
        echo "✗ Node.js is required but not installed."
        echo "  Install Node.js 20+: https://nodejs.org/"
        exit 1
    fi

    NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
    if [ "${NODE_VERSION}" -lt 20 ]; then
        echo "✗ Node.js 20+ required (found v${NODE_VERSION})."
        echo "  Update: https://nodejs.org/"
        exit 1
    fi
    echo "✓ Node.js v$(node -v | sed 's/v//') detected"

    if ! command -v npx >/dev/null 2>&1; then
        echo "✗ npx is required but not found (comes with npm)."
        exit 1
    fi
    echo "✓ npx detected"

    # Determine script directory (works for both ./install.sh and repo-relative paths)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Check if running from repo or standalone
    if [ -f "${SCRIPT_DIR}/skills/seo-image-gen/SKILL.md" ]; then
        SOURCE_DIR="${SCRIPT_DIR}"
    elif [ -f "${SCRIPT_DIR}/extensions/banana/skills/seo-image-gen/SKILL.md" ]; then
        SOURCE_DIR="${SCRIPT_DIR}/extensions/banana"
    else
        echo "✗ Cannot find extension source files."
        echo "  Run this script from the codex-seo repo: ./extensions/banana/install.sh"
        exit 1
    fi

    # Check if nanobanana-mcp is already configured
    MCP_CONFIGURED=false
    if [ -f "${MCP_CONFIG_FILE}" ]; then
        if python3 - "${MCP_CONFIG_FILE}" <<'PY' 2>/dev/null; then
import json, sys
settings_path = sys.argv[1]
with open(settings_path, 'r') as f:
    settings = json.load(f)
if 'mcpServers' in settings and 'nanobanana-mcp' in settings['mcpServers']:
    sys.exit(0)
else:
    sys.exit(1)
PY
            MCP_CONFIGURED=true
            echo "✓ nanobanana-mcp already configured in ~/.codex/config.toml"
        fi
    fi

    # If MCP not configured, prompt for API key
    if [ "${MCP_CONFIGURED}" = false ]; then
        echo ""
        echo "Google AI API key required for image generation."
        echo "Get a free key at: https://aistudio.google.com/apikey"
        echo ""

        read -rsp "Google AI API key (GOOGLE_AI_API_KEY): " GOOGLE_AI_API_KEY
        echo ""
        if [ -z "${GOOGLE_AI_API_KEY}" ]; then
            echo "✗ API key cannot be empty."
            exit 1
        fi

        # Configure MCP server
        echo "→ Configuring nanobanana-mcp server..."
        # Credentials travel in the environment (never argv, never interpolated into the source string)
        # and the settings file is written atomically with 0600 permissions.
        CODEX_SEO_SECRET="${GOOGLE_AI_API_KEY}" python3 - "${MCP_CONFIG_FILE}" <<'PY'
import os, re, sys, tempfile
path, api_key = sys.argv[1], os.environ["CODEX_SEO_SECRET"]
SERVER = "nanobanana-mcp"

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

block = '[mcp_servers."%s"]\ncommand = "npx"\nargs = ["-y", "@ycse/nanobanana-mcp@1.1.1"]\n\n[mcp_servers."%s".env]\nGOOGLE_AI_API_KEY = "%s"\n' % (SERVER, SERVER, _esc(api_key))
_write(path, _drop(_read(path), SERVER) + block)
print("Configured MCP server nanobanana-mcp in Codex config.toml")
PY
        if [ $? -ne 0 ]; then
            echo "✗ Could not auto-configure MCP server."
            echo "  See: extensions/banana/docs/BANANA-SETUP.md"
            exit 1
        fi
    fi

    # Install skill
    echo ""
    echo "→ Installing seo-image-gen skill..."
    mkdir -p "${SKILL_DIR}"
    cp "${SOURCE_DIR}/skills/seo-image-gen/SKILL.md" "${SKILL_DIR}/SKILL.md"

    # Install agent
    echo "→ Installing seo-image-gen agent..."
    mkdir -p "${AGENT_DIR}"
    cp "${SOURCE_DIR}/agents/seo-image-gen.toml" "${AGENT_DIR}/seo-image-gen.toml"

    # Copy scripts and references to skill directory for ${CODEX_SKILL_DIR} resolution
    echo "→ Installing scripts and references..."
    mkdir -p "${SKILL_DIR}/scripts" "${SKILL_DIR}/references"
    cp "${SOURCE_DIR}/scripts/"*.py "${SKILL_DIR}/scripts/"
    cp "${SOURCE_DIR}/references/"*.md "${SKILL_DIR}/references/"

    # Rewrite only files copied by this extension install. Manual installs have
    # no ${CODEX_PLUGIN_ROOT}, so the canonical launcher token becomes the
    # absolute installed path. The substitution is idempotent.
    for installed_doc in "${SKILL_DIR}/SKILL.md" "${SKILL_DIR}/references/"*.md "${AGENT_DIR}/seo-image-gen.toml"; do
        [ -f "${installed_doc}" ] || continue
        temp_doc="${installed_doc}.codex-seo-tmp"
        sed -e 's#"${CODEX_PLUGIN_ROOT}/scripts/codex-seo" run#"$HOME/.codex/skills/seo/scripts/codex-seo" run#g' \
            -e 's#"${CODEX_PLUGIN_ROOT}/scripts/codex-seo" setup#"$HOME/.codex/skills/seo/scripts/codex-seo" setup#g' \
            -e 's#"${CODEX_PLUGIN_ROOT}/scripts/codex-seo" doctor#"$HOME/.codex/skills/seo/scripts/codex-seo" doctor#g' \
            "${installed_doc}" > "${temp_doc}"
        mv "${temp_doc}" "${installed_doc}"
    done

    # Pre-warm npm package without starting the MCP server binary.
    echo "→ Pre-downloading nanobanana-mcp..."
    npx --yes --package=@ycse/nanobanana-mcp@1.1.1 -- node -e "" >/dev/null 2>&1 || true

    echo ""
    echo "✓ Banana Image Generation extension installed successfully!"
    echo ""
    echo "Usage:"
    echo "  1. Restart Codex, then run the skill"
    echo "  2. Run commands:"
    echo "     /seo image-gen og \"Professional SaaS dashboard\""
    echo "     /seo image-gen hero \"Dramatic sunset over city skyline\""
    echo "     /seo image-gen product \"Wireless headphones on marble\""
    echo "     /seo image-gen infographic \"SEO ranking factors 2026\""
    echo "     /seo image-gen custom \"Any creative concept\""
    echo "     /seo image-gen batch \"Product variations\" 3"
    echo ""
    echo "Full docs: extensions/banana/README.md"
    echo "To uninstall: ./extensions/banana/uninstall.sh"
}

main "$@"
