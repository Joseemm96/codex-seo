#!/usr/bin/env bash
set -euo pipefail

echo "Removing Firecrawl extension..."

# Remove skill directory
rm -rf "${CODEX_HOME:-${HOME}/.codex}/skills/seo-firecrawl"
echo "v Removed skill files"

# Remove MCP entry from ~/.codex/config.toml
MCP_CONFIG_FILE="${CODEX_HOME:-${HOME}/.codex}/config.toml"
if [ -f "${MCP_CONFIG_FILE}" ]; then
    python3 - "${MCP_CONFIG_FILE}" <<'PY' || echo "  Warning: Could not update ~/.codex/config.toml automatically."
import json, os, sys

settings_path = sys.argv[1]
with open(settings_path, 'r') as f:
    settings = json.load(f)

if 'mcpServers' in settings and 'firecrawl-mcp' in settings['mcpServers']:
    del settings['mcpServers']['firecrawl-mcp']
    with open(settings_path, 'w') as f:
        json.dump(settings, f, indent=2)
    print('v Removed MCP server from ~/.codex/config.toml')
else:
    print('  MCP server not found in ~/.codex/config.toml (already removed)')
PY
fi

echo ""
echo "v Firecrawl extension uninstalled."
echo "  Core Codex SEO skills are unchanged."
