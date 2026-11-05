"""Git pre-commit hook installation.

Codex plugin hooks do not include a pre-commit event. Schema validation runs
from hooks/pre-commit-schema-check.sh after hooks/install-git-hook.sh writes a
Git hook. The Windows installer still prefers the py launcher and rejects
Microsoft Store stubs.
"""

from __future__ import annotations

import os
import stat
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
PRECOMMIT = REPO_ROOT / "hooks" / "pre-commit-schema-check.sh"
INSTALL = REPO_ROOT / "hooks" / "install-git-hook.sh"
INSTALL_PS1 = REPO_ROOT / "install.ps1"
PLUGIN = REPO_ROOT / ".codex-plugin" / "plugin.json"


def test_plugin_does_not_declare_an_unsupported_hook() -> None:
    text = PLUGIN.read_text(encoding="utf-8")
    assert "hooks.json" not in text
    assert '"hooks"' not in text
    assert not (REPO_ROOT / "hooks" / "hooks.json").exists()
    installer = INSTALL.read_text(encoding="utf-8")
    assert "pre-commit-schema-check.sh" in installer
    assert "codex-seo-schema-hook" in installer
    script = PRECOMMIT.read_text(encoding="utf-8")
    assert "validate-schema.py" in script
    assert "CODEX_SEO_PYTHON" in script
    assert "CLAUDE_SEO_PYTHON" in script
    assert "run-python-hook.js" not in script


def test_windows_installer_prefers_py_launcher_and_rejects_store_stubs() -> None:
    text = INSTALL_PS1.read_text(encoding="utf-8")
    py_pos = text.index("Exe = 'py'; Args = @('-3')")
    python3_pos = text.index("Exe = 'python3'; Args = @()")
    python_pos = text.index("Exe = 'python'; Args = @()")

    assert py_pos < python3_pos < python_pos
    assert "Microsoft Store|WindowsApps|App execution alias|was not found" in text


@pytest.mark.skipif(os.name != "posix", reason="the Git hook installer is exercised with bash")
def test_git_hook_installer_writes_a_pre_commit_hook(tmp_path: Path) -> None:
    repo = tmp_path / "repo"
    hooks = repo / "hooks"
    hooks.mkdir(parents=True)
    (hooks / "pre-commit-schema-check.sh").write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
    installer = (hooks / "install-git-hook.sh").write_text(INSTALL.read_text(encoding="utf-8"), encoding="utf-8")
    del installer
    (hooks / "install-git-hook.sh").chmod(0o755)
    subprocess.run(["git", "init"], cwd=repo, check=True, capture_output=True)
    result = subprocess.run(["bash", str(hooks / "install-git-hook.sh")], cwd=repo, capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    target = repo / ".git" / "hooks" / "pre-commit"
    body = target.read_text(encoding="utf-8")
    assert "codex-seo-schema-hook" in body
    assert "pre-commit-schema-check.sh" in body
    assert target.stat().st_mode & stat.S_IXUSR

    foreign = repo / ".git" / "hooks" / "pre-commit"
    foreign.write_text("#!/bin/sh\necho foreign\n", encoding="utf-8")
    refused = subprocess.run(["bash", str(hooks / "install-git-hook.sh")], cwd=repo, capture_output=True, text=True)
    assert refused.returncode != 0
    assert foreign.read_text(encoding="utf-8") == "#!/bin/sh\necho foreign\n"
