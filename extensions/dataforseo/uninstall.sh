#!/usr/bin/env bash
set -euo pipefail

main() {
    echo "→ Uninstalling DataForSEO extension..."

    # Remove skill
    rm -rf "${CODEX_HOME:-${HOME}/.codex}/skills/seo-dataforseo"

    # Remove agent
    rm -f "${CODEX_HOME:-${HOME}/.codex}/agents/seo-dataforseo.toml"

    # Remove field config
    rm -f "${CODEX_HOME:-${HOME}/.codex}/skills/seo/dataforseo-field-config.json"

    # Remove MCP server entry from ~/.codex/config.toml
    MCP_CONFIG_FILE="${CODEX_HOME:-${HOME}/.codex}/config.toml"
    if [ -f "${MCP_CONFIG_FILE}" ]; then
        python3 - "${MCP_CONFIG_FILE}" <<'PY' 2>/dev/null || echo "  ⚠  Could not auto-remove MCP config. Remove 'dataforseo' from ~/.codex/config.toml manually."
import json, os, sys
settings_path = sys.argv[1]
with open(settings_path, 'r') as f:
    settings = json.load(f)
if 'mcpServers' in settings and 'dataforseo' in settings['mcpServers']:
    del settings['mcpServers']['dataforseo']
    if not settings['mcpServers']:
        del settings['mcpServers']
    with open(settings_path, 'w') as f:
        json.dump(settings, f, indent=2)
    print('  ✓ Removed dataforseo from ~/.codex/config.toml')
else:
    print('  ✓ No dataforseo entry in ~/.codex/config.toml')
PY
    fi

    echo "✓ DataForSEO extension uninstalled."
}

main "$@"
