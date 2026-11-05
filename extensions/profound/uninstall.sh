#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HELPER="$(cd "${SCRIPT_DIR}/../.." && pwd)/scripts/codex_config.py"
SKILL_DIR="${CODEX_HOME:-${HOME}/.codex}/skills/seo-profound"
SETTINGS_JSON="${CODEX_HOME:-${HOME}/.codex}/config.toml"

[ -d "${SKILL_DIR}" ] && rm -rf "${SKILL_DIR}" && echo "✓ Removed ${SKILL_DIR}"

if [ ! -f "${CONFIG_HELPER}" ]; then
    echo "x Missing ${CONFIG_HELPER}. The profound credential table was not removed."
    exit 1
fi
if [ -f "${SETTINGS_JSON}" ]; then
    python3 "${CONFIG_HELPER}" remove-table --path "${SETTINGS_JSON}" --table codex_seo.profound
fi
echo "✓ Profound extension uninstalled."
