#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HELPER="$(cd "${SCRIPT_DIR}/../.." && pwd)/scripts/codex_config.py"
SKILL_DIR="${CODEX_HOME:-${HOME}/.codex}/skills/seo-bing"
SETTINGS_JSON="${CODEX_HOME:-${HOME}/.codex}/config.toml"

if [ ! -f "${CONFIG_HELPER}" ]; then
    echo "x Missing ${CONFIG_HELPER}. Bing credentials were not removed."
    exit 1
fi

[ -d "${SKILL_DIR}" ] && rm -rf "${SKILL_DIR}" && echo "✓ Removed ${SKILL_DIR}"

python3 "${CONFIG_HELPER}" remove-bing --path "${SETTINGS_JSON}"
echo "✓ Removed Bing and IndexNow credentials."
