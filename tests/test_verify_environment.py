import json
import re
import subprocess
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parents[1] / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))


import verify_environment as verifier  # noqa: E402
from verify_environment import verify_environment  # noqa: E402


def test_setup_requirements_include_all_required_core_packages():
    requirements = (SCRIPTS_DIR.parent / "requirements.txt").read_text(encoding="utf-8")
    declared = {name.lower() for name in re.findall(r"(?m)^([A-Za-z0-9][A-Za-z0-9_.-]*)", requirements)}
    assert {name.lower() for name in verifier.CORE_REQUIRED_PACKAGES} <= declared


def test_dependency_import_warning_does_not_pollute_json(monkeypatch, capsys):
    def noisy_import(name):
        print("Optional library could not load native dependencies")
        raise OSError("cannot load library libgobject-2.0-0")

    monkeypatch.setattr(verifier.importlib, "import_module", noisy_import)
    result = verifier.check_dependency("weasyprint", "weasyprint")

    captured = capsys.readouterr()
    assert captured.out == ""
    assert "Optional library" in captured.err
    assert result["ok"] is False
    assert "libgobject" in result["error"]


def test_verify_environment_returns_expected_shape():
    result = verify_environment()
    assert "python" in result
    assert "dependencies" in result
    assert "paths" in result
    assert isinstance(result["dependencies"], list)
    assert "ready" in result
    assert "full_ready" in result["capabilities"]
    assert "premium_report_ready" in result["capabilities"]
    assert "google_api_package_ready" in result["capabilities"]
    assert "missing_report" in result
    assert "missing_visual" in result
    assert "missing_google_api" in result


def test_verify_environment_cli_survives_without_site_packages():
    completed = subprocess.run(
        [sys.executable, "-S", str(SCRIPTS_DIR / "verify_environment.py"), "--json"],
        cwd=SCRIPTS_DIR.parent,
        capture_output=True,
        text=True,
        check=False,
    )
    assert completed.returncode == 1, completed.stderr
    result = json.loads(completed.stdout)
    assert "dependencies" in result
    assert "beautifulsoup4" in result["missing_required"]
    assert "google-api-python-client" in result["missing_google_api"]
