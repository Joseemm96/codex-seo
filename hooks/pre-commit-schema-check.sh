#!/usr/bin/env bash
set -euo pipefail

# Git pre-commit schema and SEO checks.
# Install from a clone with: bash hooks/install-git-hook.sh
# Codex plugin manifests do not run this file automatically.

ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
VALIDATOR="${ROOT}/hooks/validate-schema.py"
SEO_CHECK="${ROOT}/hooks/pre-commit-seo-check.sh"
PYTHON_BIN="${CODEX_SEO_PYTHON:-${CLAUDE_SEO_PYTHON:-}}"

if [ -z "${PYTHON_BIN}" ]; then
    if command -v python3 >/dev/null 2>&1; then
        PYTHON_BIN="python3"
    else
        PYTHON_BIN="python"
    fi
fi

if ! git diff --cached --quiet 2>/dev/null; then
    :
else
    exit 0
fi

STATUS=0
STAGED_FILES="$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -E '\.(html|htm|php|jsx|tsx|vue|svelte|json)$' || true)"
for file in ${STAGED_FILES}; do
    if [ -f "${file}" ]; then
        "${PYTHON_BIN}" "${VALIDATOR}" "${file}" || STATUS=$?
    fi
done

if [ -x "${SEO_CHECK}" ]; then
    "${SEO_CHECK}" || STATUS=$?
fi

exit "${STATUS}"
