#!/usr/bin/env bash
set -euo pipefail

echo "Removing Firecrawl extension..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HELPER="$(cd "${SCRIPT_DIR}/../.." && pwd)/scripts/codex_config.py"
MCP_CONFIG_FILE="${CODEX_HOME:-${HOME}/.codex}/config.toml"

rm -rf "${CODEX_HOME:-${HOME}/.codex}/skills/seo-firecrawl"
echo "v Removed skill files"

if [ ! -f "${CONFIG_HELPER}" ]; then
    echo "x Missing ${CONFIG_HELPER}. The firecrawl-mcp server was not removed."
    exit 1
fi
if [ -f "${MCP_CONFIG_FILE}" ]; then
    python3 "${CONFIG_HELPER}" remove-mcp --path "${MCP_CONFIG_FILE}" --server firecrawl-mcp
fi

echo ""
echo "v Firecrawl extension uninstalled."
echo "  Core Codex SEO skills are unchanged."
