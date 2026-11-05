#!/usr/bin/env bash
# Codex SEO: Profound (LLM citation tracker) extension installer.
#
# Profound tracks brand citation rates across major LLMs and exposes
# them as structured time-series. Pairs with seo-seranking (which
# samples mention rates) for triangulated AI visibility data.
set -euo pipefail

main() {
    SKILL_DIR="${CODEX_HOME:-${HOME}/.codex}/skills"
    SETTINGS_JSON="${CODEX_HOME:-${HOME}/.codex}/config.toml"

    echo "════════════════════════════════════════"
    echo "║   Codex SEO: Profound extension     ║"
    echo "════════════════════════════════════════"

    command -v python3 >/dev/null 2>&1 || { echo "✗ Python 3 required."; exit 1; }
    [ ! -d "${SKILL_DIR}/seo" ] && { echo "✗ codex-seo base not installed."; exit 1; }

    SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd)"

    read -rsp "Profound API key: " PROFOUND_KEY
    echo
    [ -z "${PROFOUND_KEY}" ] && { echo "✗ No key provided."; exit 1; }

    mkdir -p "${SKILL_DIR}/seo-profound"
    cp "${SOURCE_DIR}/skills/seo-profound/SKILL.md" "${SKILL_DIR}/seo-profound/SKILL.md"

    CONFIG_HELPER="$(cd "${SOURCE_DIR}/../.." && pwd)/scripts/codex_config.py"
    if [ ! -f "${CONFIG_HELPER}" ]; then
        echo "x Missing ${CONFIG_HELPER}"
        exit 1
    fi
    CODEX_SEO_SECRET="${PROFOUND_KEY}" python3 "${CONFIG_HELPER}" upsert-table \
        --path "${SETTINGS_JSON}" \
        --table codex_seo.profound \
        --env-from PROFOUND_API_KEY=CODEX_SEO_SECRET

    echo "Done. Try: /seo profound citations brandname"
}
main "$@"
