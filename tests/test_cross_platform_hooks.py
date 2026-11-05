"""Codex pre-commit hook configuration.

Claude Code's node hook bridge (run-python-hook.js) does not map to Codex.
Schema validation runs from hooks/pre-commit-schema-check.sh, which calls
hooks/validate-schema.py. The Windows installer still prefers the py launcher
and rejects Microsoft Store stubs.
"""

from __future__ import annotations

import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
HOOKS_JSON = REPO_ROOT / "hooks" / "hooks.json"
PRECOMMIT = REPO_ROOT / "hooks" / "pre-commit-schema-check.sh"
INSTALL_PS1 = REPO_ROOT / "install.ps1"


def test_schema_hook_uses_precommit_runner() -> None:
    config = json.loads(HOOKS_JSON.read_text(encoding="utf-8"))
    handler = config["hooks"]["pre-commit"][0]
    assert handler["command"] == "hooks/pre-commit-schema-check.sh"
    text = PRECOMMIT.read_text(encoding="utf-8")
    assert "validate-schema.py" in text
    assert "CODEX_SEO_PYTHON" in text
    assert "CLAUDE_SEO_PYTHON" in text
    assert "run-python-hook.js" not in text


def test_windows_installer_prefers_py_launcher_and_rejects_store_stubs() -> None:
    text = INSTALL_PS1.read_text(encoding="utf-8")
    py_pos = text.index("Exe = 'py'; Args = @('-3')")
    python3_pos = text.index("Exe = 'python3'; Args = @()")
    python_pos = text.index("Exe = 'python'; Args = @()")

    assert py_pos < python3_pos < python_pos
    assert "Microsoft Store|WindowsApps|App execution alias|was not found" in text
