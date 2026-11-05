#!/usr/bin/env bash
# Codex SEO: Matomo extension installer.
#
# Self-hosted (or Matomo Cloud) Reporting API. Provides organic traffic,
# landing pages, device / country breakdowns, and referrer analysis as a
# GA4 alternative or complement.
#
# Prereq: a Matomo instance URL, an API token_auth, and (optionally) a
# default site ID.
set -euo pipefail

main() {
    SKILL_DIR="${CODEX_HOME:-${HOME}/.codex}/skills"
    AGENTS_DIR="${CODEX_HOME:-${HOME}/.codex}/agents"

    echo "════════════════════════════════════════"
    echo "║ Codex SEO - Matomo extension       ║"
    echo "════════════════════════════════════════"

    command -v python3 >/dev/null 2>&1 || { echo "✗ Python 3 required."; exit 1; }
    [ ! -d "${SKILL_DIR}/seo" ] && { echo "✗ codex-seo base not installed."; exit 1; }

    SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd)"
    REPO_ROOT="$(cd "${SOURCE_DIR}/../.." >/dev/null 2>&1 && pwd)"
    MATOMO_AUTH="${REPO_ROOT}/scripts/matomo_auth.py"

    read -rp "Matomo instance URL (e.g. https://analytics.example.com): " MATOMO_URL
    [ -z "${MATOMO_URL}" ] && { echo "✗ Matomo URL required."; exit 1; }

    # Every Matomo request goes through the SSRF guard, which refuses private
    # addresses unless they are named in CODEX_SEO_LOCAL_TARGETS. Tell the
    # user now, with the exact host:port, rather than at the first failed call.
    if [ -f "${MATOMO_AUTH}" ]; then
        HINT="$(python3 "${MATOMO_AUTH}" --local-target-hint "${MATOMO_URL}" 2>/dev/null || true)"
        if [ -n "${HINT}" ]; then
            echo
            echo "! ${MATOMO_URL} is on a private address."
            echo "  ${HINT}"
            echo
        fi
    fi

    read -rsp "Matomo API token_auth (32-char hex): " MATOMO_TOKEN
    echo
    [ -z "${MATOMO_TOKEN}" ] && { echo "✗ Matomo token_auth required."; exit 1; }

    read -rp "Default site ID (idSite, optional, e.g. 1): " MATOMO_SITE_ID
    echo

    mkdir -p "${SKILL_DIR}/seo-matomo"
    cp "${SOURCE_DIR}/skills/seo-matomo/SKILL.md" "${SKILL_DIR}/seo-matomo/SKILL.md"
    echo "✓ Installed skill: ${SKILL_DIR}/seo-matomo/SKILL.md"

    mkdir -p "${AGENTS_DIR}"
    cp "${SOURCE_DIR}/agents/seo-matomo.toml" "${AGENTS_DIR}/seo-matomo.toml"
    echo "✓ Installed agent: ${AGENTS_DIR}/seo-matomo.toml"

    # Credentials go to ~/.config/codex-seo/matomo.json (0600, atomic), not
    # into ~/.codex/config.toml: settings.json is a general-purpose config
    # file that tooling reads, prints, and syncs, and an API token has no
    # business in it. matomo_auth.py still falls back to the MATOMO_*
    # environment variables, which stays the right choice on a shared machine.
    [ -f "${MATOMO_AUTH}" ] || { echo "✗ ${MATOMO_AUTH} not found."; exit 1; }
    CODEX_SEO_SECRET="${MATOMO_TOKEN}" python3 - "${MATOMO_AUTH}" "${MATOMO_URL}" "${MATOMO_SITE_ID}" <<'PY'
import importlib.util, os, sys

# PowerShell 5.1 drops an empty string argument to a native command, so the
# optional site ID may simply not arrive. Tolerate that rather than crashing
# the installer after the token has already been typed.
args = sys.argv[1:]
auth_path, url = args[0], args[1]
site = args[2] if len(args) > 2 else ""
token = os.environ["CODEX_SEO_SECRET"]  # environment, not argv (ps)
spec = importlib.util.spec_from_file_location("matomo_auth", auth_path)
matomo_auth = importlib.util.module_from_spec(spec)
sys.modules["matomo_auth"] = matomo_auth
spec.loader.exec_module(matomo_auth)

matomo_auth.save_config({
    "matomo_url": url,
    "matomo_token": token,
    "matomo_site_id": site,
})
print("Wrote Matomo credentials to " + matomo_auth.CONFIG_PATH + " (0600)")
PY

    echo
    echo "Done. Verify with:"
    echo "  \"\${CODEX_PLUGIN_ROOT}/scripts/codex-seo\" run matomo_auth.py --check"
    echo "  \"\${CODEX_PLUGIN_ROOT}/scripts/codex-seo\" run matomo_report.py check --json"
    echo "Credentials live in ~/.config/codex-seo/matomo.json (0600)."
    echo "MATOMO_URL / MATOMO_API_TOKEN / MATOMO_SITE_ID still override the file."
    echo "Full docs: extensions/matomo/docs/MATOMO-SETUP.md"
}
main "$@"