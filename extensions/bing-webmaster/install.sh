#!/usr/bin/env bash
# Codex SEO: Bing Webmaster + IndexNow extension installer.
#
# Wires the existing scripts/bing_webmaster.py and indexnow_submit.py into
# a discoverable seo-bing skill and stores the Bing Webmaster Tools API
# key + IndexNow host key in ~/.codex/config.toml.
#
# Microsoft Copilot citations are fed by the Bing index, making this the
# canonical extension for "AI search visibility outside Google".
set -euo pipefail

main() {
    SKILL_DIR="${CODEX_HOME:-${HOME}/.codex}/skills"
    SETTINGS_JSON="${CODEX_HOME:-${HOME}/.codex}/config.toml"

    echo "════════════════════════════════════════"
    echo "║ Codex SEO: Bing Webmaster + IndexNow ║"
    echo "════════════════════════════════════════"

    command -v python3 >/dev/null 2>&1 || { echo "✗ Python 3 required."; exit 1; }
    [ ! -d "${SKILL_DIR}/seo" ] && { echo "✗ codex-seo base not installed."; exit 1; }

    SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd)"

    read -rsp "Bing Webmaster Tools API key (https://www.bing.com/webmasters/api): " BING_KEY
    echo
    read -rp  "IndexNow host key (32+ chars, you'll publish this at /<key>.txt): " INDEXNOW_KEY
    read -rp  "IndexNow keyLocation URL (https://example.com/<key>.txt): " INDEXNOW_LOC

    [ -z "${BING_KEY}" ] && [ -z "${INDEXNOW_KEY}" ] && {
        echo "✗ Provide at least one of: Bing API key, IndexNow key."; exit 1;
    }

    mkdir -p "${SKILL_DIR}/seo-bing"
    cp "${SOURCE_DIR}/skills/seo-bing/SKILL.md" "${SKILL_DIR}/seo-bing/SKILL.md"

    CONFIG_HELPER="$(cd "${SOURCE_DIR}/../.." && pwd)/scripts/codex_config.py"
    if [ ! -f "${CONFIG_HELPER}" ]; then
        echo "x Missing ${CONFIG_HELPER}"
        exit 1
    fi
    # Bing goes to the backlink credential file. IndexNow goes to indexnow.json.
    # store-bing re-reads both and exits non-zero if a tool cannot see the value.
    # A legacy [codex_seo.bing] table is removed from config.toml.
    CODEX_SEO_SECRET="${BING_KEY}" \
    CODEX_SEO_INDEXNOW_KEY="${INDEXNOW_KEY}" \
    CODEX_SEO_INDEXNOW_LOCATION="${INDEXNOW_LOC}" \
    python3 "${CONFIG_HELPER}" store-bing --path "${SETTINGS_JSON}"

    echo
    echo "Done. Credentials are in ~/.config/codex-seo/backlinks-api.json (Bing)"
    echo "and ~/.config/codex-seo/indexnow.json (IndexNow)."
    echo "Verify with:"
    echo "  \"\${CODEX_PLUGIN_ROOT}/scripts/codex-seo\" run backlinks_auth.py --check bing"
    echo "  \"\${CODEX_PLUGIN_ROOT}/scripts/codex-seo\" run indexnow_submit.py --host example.com --verify-only"
}
main "$@"
