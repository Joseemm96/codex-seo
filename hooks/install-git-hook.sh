#!/usr/bin/env bash
# Install the schema and SEO checks as this repository's Git pre-commit hook.
#
# Codex plugin hooks do not include a pre-commit event. This script writes a
# Git hook that calls hooks/pre-commit-schema-check.sh by absolute path.
# It refuses to replace an existing hook that this installer did not write.
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
RUNNER="${ROOT}/hooks/pre-commit-schema-check.sh"
MARKER="# codex-seo-schema-hook"

if [ ! -f "${RUNNER}" ]; then
    echo "x Missing ${RUNNER}" >&2
    exit 1
fi
if ! git -C "${ROOT}" rev-parse --git-path hooks >/dev/null 2>&1; then
    echo "x ${ROOT} is not a Git checkout. This hook is for a local clone, not a plugin install." >&2
    exit 1
fi

HOOKS_DIR="$(git -C "${ROOT}" rev-parse --git-path hooks)"
case "${HOOKS_DIR}" in
    /*) ;;
    *) HOOKS_DIR="${ROOT}/${HOOKS_DIR}" ;;
esac
mkdir -p "${HOOKS_DIR}"
TARGET="${HOOKS_DIR}/pre-commit"

if [ -e "${TARGET}" ] && ! grep -q "${MARKER}" "${TARGET}" 2>/dev/null; then
    echo "x Refusing to replace existing ${TARGET}. Move it aside and rerun." >&2
    exit 1
fi

{
    printf '%s\n' "#!/usr/bin/env bash"
    printf '%s\n' "${MARKER}"
    printf 'exec %q "$@"\n' "${RUNNER}"
} > "${TARGET}"
chmod +x "${TARGET}" "${RUNNER}"
echo "Installed Git pre-commit hook: ${TARGET}"
