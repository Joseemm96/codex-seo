#!/usr/bin/env bash
set -euo pipefail

# DataForSEO Extension Installer for Codex SEO
# Wraps everything in main() to prevent partial execution on network failure

main() {
    SKILL_DIR="${CODEX_HOME:-${HOME}/.codex}/skills/seo-dataforseo"
    AGENT_DIR="${CODEX_HOME:-${HOME}/.codex}/agents"
    SEO_SKILL_DIR="${CODEX_HOME:-${HOME}/.codex}/skills/seo"
    # MCP servers live in ~/.codex/config.toml (the file `claude mcp add` writes).
    # NOT ~/.codex/config.toml - `mcpServers` is not a key Claude Code reads
    # there, so entries written to settings.json silently never load.
    MCP_CONFIG_FILE="${CODEX_HOME:-${HOME}/.codex}/config.toml"

    echo "════════════════════════════════════════"
    echo "║   DataForSEO Extension - Installer   ║"
    echo "║   For Codex SEO                     ║"
    echo "════════════════════════════════════════"
    echo ""

    # Support both traditional (curl|bash → ~/.codex/skills/seo) and marketplace
    # (plugin install → ~/.codex/plugins/cache/.../skills/seo) installations.
    # Resolve early using BASH_SOURCE so it works even when run from the plugin cache.
    _EARLY_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    _PLUGIN_SEO_DIR="$(cd "${_EARLY_SCRIPT_DIR}/../.." 2>/dev/null && pwd)/skills/seo"
    if [ ! -d "${SEO_SKILL_DIR}" ] && [ -d "${_PLUGIN_SEO_DIR}" ]; then
        SEO_SKILL_DIR="${_PLUGIN_SEO_DIR}"
    fi
    if [ ! -d "${SEO_SKILL_DIR}" ]; then
        _GLOB_MATCH=$(ls -d "${CODEX_HOME:-${HOME}/.codex}/plugins/cache/*/codex-seo/"*/skills/seo 2>/dev/null | tail -n1 || true)
        [ -n "${_GLOB_MATCH}" ] && [ -d "${_GLOB_MATCH}" ] && SEO_SKILL_DIR="${_GLOB_MATCH}"
    fi

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

    # Prompt for credentials
    echo ""
    echo "DataForSEO API credentials required."
    echo "Sign up at: https://app.dataforseo.com/register"
    echo ""

    read -rp "DataForSEO username (email): " DFSE_USERNAME
    if [ -z "${DFSE_USERNAME}" ]; then
        echo "✗ Username cannot be empty."
        exit 1
    fi

    read -rsp "DataForSEO password: " DFSE_PASSWORD
    echo ""
    if [ -z "${DFSE_PASSWORD}" ]; then
        echo "✗ Password cannot be empty."
        exit 1
    fi

    # Determine script directory (works for both ./install.sh and curl|bash)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Check if running from repo or standalone
    if [ -f "${SCRIPT_DIR}/skills/seo-dataforseo/SKILL.md" ]; then
        SOURCE_DIR="${SCRIPT_DIR}"
    elif [ -f "${SCRIPT_DIR}/extensions/dataforseo/skills/seo-dataforseo/SKILL.md" ]; then
        SOURCE_DIR="${SCRIPT_DIR}/extensions/dataforseo"
    else
        echo "✗ Cannot find extension source files."
        echo "  Run this script from the codex-seo repo: ./extensions/dataforseo/install.sh"
        exit 1
    fi

    # Install skill
    echo ""
    echo "→ Installing DataForSEO skill..."
    mkdir -p "${SKILL_DIR}"
    cp "${SOURCE_DIR}/skills/seo-dataforseo/SKILL.md" "${SKILL_DIR}/SKILL.md"

    # Install agent
    echo "→ Installing DataForSEO agent..."
    mkdir -p "${AGENT_DIR}"
    cp "${SOURCE_DIR}/agents/seo-dataforseo.toml" "${AGENT_DIR}/seo-dataforseo.toml"

    # Install field config
    echo "→ Installing field config..."
    cp "${SOURCE_DIR}/field-config.json" "${SEO_SKILL_DIR}/dataforseo-field-config.json"

    # Merge MCP config into ~/.codex/config.toml
    echo "→ Configuring MCP server..."
    FIELD_CONFIG_PATH="${SEO_SKILL_DIR}/dataforseo-field-config.json"
    CONFIG_HELPER="$(cd "${SOURCE_DIR}/../.." && pwd)/scripts/codex_config.py"
    if [ ! -f "${CONFIG_HELPER}" ]; then
        echo "x Missing ${CONFIG_HELPER}"
        exit 1
    fi

    # Credentials stay in the environment. The helper replaces quoted or bare
    # dataforseo tables and validates the full document before saving.
    if ! CODEX_SEO_USERNAME="${DFSE_USERNAME}" \
        CODEX_SEO_SECRET="${DFSE_PASSWORD}" \
        CODEX_SEO_FIELD_CONFIG="${FIELD_CONFIG_PATH}" \
        CODEX_SEO_ENABLED_MODULES="SERP,KEYWORDS_DATA,ONPAGE,DATAFORSEO_LABS,BACKLINKS,DOMAIN_ANALYTICS,BUSINESS_DATA,CONTENT_ANALYSIS,AI_OPTIMIZATION" \
        python3 "${CONFIG_HELPER}" upsert-mcp \
        --path "${MCP_CONFIG_FILE}" \
        --server dataforseo \
        --command npx \
        --arg=-y \
        --arg=dataforseo-mcp-server@2.8.10 \
        --env-from DATAFORSEO_USERNAME=CODEX_SEO_USERNAME \
        --env-from DATAFORSEO_PASSWORD=CODEX_SEO_SECRET \
        --env-from ENABLED_MODULES=CODEX_SEO_ENABLED_MODULES \
        --env-from FIELD_CONFIG_PATH=CODEX_SEO_FIELD_CONFIG
    then
        echo "  ⚠  Could not auto-configure MCP server."
        echo "  Add the dataforseo server manually to ~/.codex/config.toml"
        echo "  See: extensions/dataforseo/docs/DATAFORSEO-SETUP.md"
    fi

    # Pre-warm npm package without starting the MCP server binary.
    echo "→ Pre-downloading dataforseo-mcp-server..."
    npx --yes --package=dataforseo-mcp-server@2.8.10 -- node -e "" >/dev/null 2>&1 || true

    echo ""
    echo "✓ DataForSEO extension installed successfully!"
    echo ""
    echo "Usage:"
    echo "  1. Restart Codex, then run the skill"
    echo "  2. Run commands:"
    echo "     /seo dataforseo serp best coffee shops"
    echo "     /seo dataforseo keywords seo tools"
    echo "     /seo dataforseo backlinks example.com"
    echo "     /seo dataforseo ai-mentions your brand"
    echo ""
    echo "All 23 commands: see extensions/dataforseo/README.md"
    echo "To uninstall: ./extensions/dataforseo/uninstall.sh"
}

main "$@"
