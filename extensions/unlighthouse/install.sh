#!/usr/bin/env bash
# Codex SEO: Unlighthouse extension installer.
#
# Wraps the existing scripts/unlighthouse_run.py into a discoverable
# seo-unlighthouse skill. No API keys: Unlighthouse is fully local,
# MIT-licensed, runs on top of Lighthouse via npx.
set -euo pipefail

main() {
    SKILL_DIR="${CODEX_HOME:-${HOME}/.codex}/skills"
    SEO_SKILL_DIR="${SKILL_DIR}/seo"

    echo "════════════════════════════════════════"
    echo "║   Codex SEO: Unlighthouse            ║"
    echo "════════════════════════════════════════"

    command -v python3 >/dev/null 2>&1 || { echo "✗ Python 3 required."; exit 1; }
    command -v npx     >/dev/null 2>&1 || { echo "✗ Node 18+ / npx required."; exit 1; }

    # Support both traditional (curl|bash → ~/.codex/skills/seo) and marketplace
    # (plugin install → ${CODEX_PLUGIN_ROOT}, or ~/.codex/plugins/cache/.../skills/seo)
    # installations. A plugin install never populates ~/.codex/skills/seo, so that
    # check alone would always abort; check the plugin locations too before failing.
    SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd)"
    if [ ! -d "${SEO_SKILL_DIR}" ] && [ -n "${CODEX_PLUGIN_ROOT:-}" ] && [ -d "${CODEX_PLUGIN_ROOT}/skills/seo" ]; then
        SEO_SKILL_DIR="${CODEX_PLUGIN_ROOT}/skills/seo"
    fi
    if [ ! -d "${SEO_SKILL_DIR}" ]; then
        _PLUGIN_SEO_DIR="$(cd "${SOURCE_DIR}/../.." 2>/dev/null && pwd)/skills/seo"
        [ -d "${_PLUGIN_SEO_DIR}" ] && SEO_SKILL_DIR="${_PLUGIN_SEO_DIR}"
    fi
    if [ ! -d "${SEO_SKILL_DIR}" ]; then
        _GLOB_MATCH=$(ls -d "${CODEX_HOME:-${HOME}/.codex}/plugins/cache/"*/codex-seo/*/skills/seo 2>/dev/null | tail -n1 || true)
        [ -n "${_GLOB_MATCH}" ] && [ -d "${_GLOB_MATCH}" ] && SEO_SKILL_DIR="${_GLOB_MATCH}"
    fi
    [ ! -d "${SEO_SKILL_DIR}" ] && { echo "✗ codex-seo base not installed."; exit 1; }

    echo "→ Pre-warming unlighthouse..."
    npx --yes --package=unlighthouse@0.13.5 unlighthouse-ci --help >/dev/null 2>&1 || true

    mkdir -p "${SKILL_DIR}/seo-unlighthouse"
    cp "${SOURCE_DIR}/skills/seo-unlighthouse/SKILL.md" "${SKILL_DIR}/seo-unlighthouse/SKILL.md"
    echo "✓ Installed skill: ${SKILL_DIR}/seo-unlighthouse"
    echo "Done. Try: /seo unlighthouse https://example.com"
}
main "$@"
