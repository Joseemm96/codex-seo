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
    CONFIG_HELPER="$(cd "${SOURCE_DIR}/../.." && pwd)/scripts/codex_config.py"
    if [ ! -f "${CONFIG_HELPER}" ]; then
        echo "x Missing ${CONFIG_HELPER}"
        exit 1
    fi
    CODEX_SEO_SECRET="${AHREFS_TOKEN}" python3 "${CONFIG_HELPER}" upsert-mcp \
        --path "${MCP_CONFIG_JSON}" \
        --server ahrefs \
        --command npx \
        --arg=--yes \
        --arg=--package=@ahrefs/mcp@0.0.11 \
        --arg=mcp \
        --env-from AHREFS_API_TOKEN=CODEX_SEO_SECRET

    echo
    echo "Done. Open a new Claude Code session and run:"
    echo "  /seo ahrefs metrics https://example.com"
    echo
    echo "Full docs: extensions/ahrefs/docs/AHREFS-SETUP.md"
}

main "$@"
