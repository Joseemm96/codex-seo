#!/usr/bin/env bash
set -euo pipefail

main() {
    echo "→ Uninstalling Banana Image Generation extension..."

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    CONFIG_HELPER="$(cd "${SCRIPT_DIR}/../.." && pwd)/scripts/codex_config.py"
    MCP_CONFIG_FILE="${CODEX_HOME:-${HOME}/.codex}/config.toml"

    rm -rf "${CODEX_HOME:-${HOME}/.codex}/skills/seo-image-gen"
    rm -f "${CODEX_HOME:-${HOME}/.codex}/agents/seo-image-gen.toml"

    if [ -f "${MCP_CONFIG_FILE}" ]; then
        if [ -d "${CODEX_HOME:-${HOME}/.codex}/skills/banana" ]; then
            echo "  i  Standalone banana skill detected at ~/.codex/skills/banana/"
            echo "  i  Keeping nanobanana-mcp in ~/.codex/config.toml (used by standalone skill)"
        else
            if [ ! -f "${CONFIG_HELPER}" ]; then
                echo "x Missing ${CONFIG_HELPER}. nanobanana-mcp was not removed."
                exit 1
            fi
            python3 "${CONFIG_HELPER}" remove-mcp --path "${MCP_CONFIG_FILE}" --server nanobanana-mcp
        fi
    fi

    echo "✓ Banana Image Generation extension uninstalled."
}

main "$@"
