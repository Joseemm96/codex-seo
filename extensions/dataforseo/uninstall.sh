#!/usr/bin/env bash
set -euo pipefail

main() {
    echo "→ Uninstalling DataForSEO extension..."

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    CONFIG_HELPER="$(cd "${SCRIPT_DIR}/../.." && pwd)/scripts/codex_config.py"
    MCP_CONFIG_FILE="${CODEX_HOME:-${HOME}/.codex}/config.toml"

    rm -rf "${CODEX_HOME:-${HOME}/.codex}/skills/seo-dataforseo"
    rm -f "${CODEX_HOME:-${HOME}/.codex}/agents/seo-dataforseo.toml"
    rm -f "${CODEX_HOME:-${HOME}/.codex}/skills/seo/dataforseo-field-config.json"

    if [ ! -f "${CONFIG_HELPER}" ]; then
        echo "x Missing ${CONFIG_HELPER}. The dataforseo MCP server was not removed."
        exit 1
    fi
    if [ -f "${MCP_CONFIG_FILE}" ]; then
        python3 "${CONFIG_HELPER}" remove-mcp --path "${MCP_CONFIG_FILE}" --server dataforseo
    fi

    echo "✓ DataForSEO extension uninstalled."
}

main "$@"
