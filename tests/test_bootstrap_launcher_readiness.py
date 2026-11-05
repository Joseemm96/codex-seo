"""Bootstrap and `/seo setup` share the launcher readiness file."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"
sys.path.insert(0, str(SCRIPTS))

import bootstrap_environment as bootstrap_module  # noqa: E402


def _ready_verification() -> dict:
    return {
        "ready": True,
        "capabilities": {
            "core_ready": True,
            "visual_ready": False,
            "premium_report_ready": False,
            "full_ready": False,
        },
    }


def _fake_run(cmd: list[str], cwd: Path | None = None):
    if "verify_environment.py" in " ".join(cmd):
        return {
            "cmd": cmd,
            "returncode": 0,
            "stdout": json.dumps(_ready_verification()),
            "stderr": "",
            "stdout_truncated": False,
            "stderr_truncated": False,
            "ok": True,
        }
    return {
        "cmd": cmd,
        "returncode": 0,
        "stdout": "",
        "stderr": "",
        "stdout_truncated": False,
        "stderr_truncated": False,
        "ok": True,
    }


@pytest.mark.skipif(os.name == "nt", reason="launcher shim is a POSIX shell script")
def test_bootstrap_writes_runtime_state_and_launcher_runs(monkeypatch, tmp_path: Path) -> None:
    data = tmp_path / "manual-install"
    data.mkdir()
    monkeypatch.setenv("CODEX_SEO_DATA_DIR", str(data))
    venv_bin = data / ".venv" / "bin"
    venv_bin.mkdir(parents=True)
    shim = venv_bin / "python"
    shim.write_text(f"#!/bin/sh\nexec {sys.executable} \"$@\"\n", encoding="utf-8")
    shim.chmod(0o755)
    monkeypatch.setattr(bootstrap_module, "run_command", _fake_run)

    result = bootstrap_module.bootstrap_environment(venv_dir=data / ".venv", install_playwright_browser=False)

    assert result["ok"] is True
    assert result["runtime_state"] == "written"
    state_path = data / "runtime-state.json"
    state = json.loads(state_path.read_text(encoding="utf-8"))
    assert state["runtime_schema"] == 1
    assert state["python"] == f"{sys.version_info.major}.{sys.version_info.minor}"

    env = os.environ.copy()
    env["CODEX_SEO_DATA_DIR"] = str(data)
    env["CODEX_SEO_PYTHON"] = sys.executable
    doctor = subprocess.run(
        ["bash", str(SCRIPTS / "codex-seo"), "doctor", "--json"],
        cwd=ROOT,
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )
    assert doctor.returncode == 0, doctor.stderr
    assert json.loads(doctor.stdout)["ready"] is True
    run = subprocess.run(
        ["bash", str(SCRIPTS / "codex-seo"), "run", "metadata_template.py", "--help"],
        cwd=ROOT,
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )
    assert run.returncode == 0, run.stderr
    assert "usage:" in run.stdout.lower()


def test_custom_venv_does_not_mark_the_launcher_ready(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.delenv("CODEX_SEO_DATA_DIR", raising=False)
    venv = tmp_path / "custom-venv"
    python_path = venv / "bin" / "python"
    python_path.parent.mkdir(parents=True)
    python_path.write_text("", encoding="utf-8")
    monkeypatch.setattr(bootstrap_module, "run_command", _fake_run)

    result = bootstrap_module.bootstrap_environment(venv_dir=venv, install_playwright_browser=False)

    assert result["ok"] is True
    assert result["runtime_state"] == "skipped"
    assert not (ROOT / "runtime-state.json").exists()
