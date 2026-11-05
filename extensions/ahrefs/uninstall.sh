#!/usr/bin/env bash
# Codex SEO: Ahrefs extension uninstaller.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HELPER="$(cd "${SCRIPT_DIR}/../.." && pwd)/scripts/codex_config.py"
SKILL_DIR="${CODEX_HOME:-${HOME}/.codex}/skills/seo-ahrefs"
MCP_CONFIG_JSON="${CODEX_HOME:-${HOME}/.codex}/config.toml"

if [ -d "${SKILL_DIR}" ]; then
    rm -rf "${SKILL_DIR}"
    echo "✓ Removed ${SKILL_DIR}"
fi

if [ ! -f "${CONFIG_HELPER}" ]; then
    echo "x Missing ${CONFIG_HELPER}. The ahrefs MCP server was not removed."
    exit 1
fi
if [ -f "${MCP_CONFIG_JSON}" ]; then
    python3 "${CONFIG_HELPER}" remove-mcp --path "${MCP_CONFIG_JSON}" --server ahrefs
fi

echo "Done."
