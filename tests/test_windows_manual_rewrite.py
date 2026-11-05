"""Windows manual installs rewrite skills and agents to a real Python command."""

from __future__ import annotations

import shutil
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import rewrite_manual_paths as rewrite  # noqa: E402


def test_windows_launcher_quotes_spaces_and_apostrophes() -> None:
    command = rewrite.windows_launcher_command(
        r"C:\Program Files\Python\python.exe",
        [],
        r"C:\Users\O'Brien\.codex\skills\seo\scripts\runtime.py",
    )
    assert command == (
        "& 'C:\\Program Files\\Python\\python.exe' "
        "'C:\\Users\\O''Brien\\.codex\\skills\\seo\\scripts\\runtime.py'"
    )


def test_rewrite_updates_skills_and_agent_toml(tmp_path: Path) -> None:
    skills = tmp_path / "skills"
    skill = skills / "seo"
    skill.mkdir(parents=True)
    (skill / "SKILL.md").write_text(
        'Run "${CODEX_PLUGIN_ROOT}/scripts/codex-seo" run fetch_page.py\n'
        "See ${CODEX_PLUGIN_ROOT}/skills/seo/references/x.md\n",
        encoding="utf-8",
    )
    agents = tmp_path / "agents"
    agents.mkdir()
    (agents / "seo-technical.toml").write_text(
        '"${CODEX_PLUGIN_ROOT}/scripts/codex-seo" doctor\n',
        encoding="utf-8",
    )
    runtime = r"C:\Users\Vessel\.codex\skills\seo\scripts\runtime.py"
    launcher = rewrite.windows_launcher_command(r"C:\Python\python.exe", ["-3"], runtime)
    changed = rewrite.rewrite_tree(
        skills_root=skills,
        agent_dir=agents,
        skills_prefix=r"C:\Users\Vessel\.codex\skills" + "\\",
        launcher=launcher,
    )
    assert changed == 2
    skill_text = (skill / "SKILL.md").read_text(encoding="utf-8")
    agent_text = (agents / "seo-technical.toml").read_text(encoding="utf-8")
    expected = "& 'C:\\Python\\python.exe' '-3' 'C:\\Users\\Vessel\\.codex\\skills\\seo\\scripts\\runtime.py'"
    toml_expected = expected.replace("\\", "/")
    assert f"{expected} run fetch_page.py" in skill_text
    assert f"{toml_expected} doctor" in agent_text
    assert r"C:\Users\Vessel\.codex\skills\seo/references/x.md" in skill_text
    assert "${CODEX_PLUGIN_ROOT}" not in skill_text
    assert "${CODEX_PLUGIN_ROOT}" not in agent_text


def test_windows_rewrite_keeps_real_agent_toml_valid(tmp_path: Path) -> None:
    """Rewrite the shipped agents, then parse every file.

    A one-line fixture never enters a TOML basic string, so it cannot see
    that Windows backslashes are invalid escapes.
    """
    agents = tmp_path / "agents"
    skills = tmp_path / "skills"
    skills.mkdir()
    shutil.copytree(ROOT / "agents", agents)
    paths = sorted(agents.glob("seo-*.toml"))
    assert len(paths) >= 25
    originals = {path.name: path.read_text(encoding="utf-8") for path in paths}
    for original in originals.values():
        tomllib.loads(original)

    changed = rewrite.rewrite_tree(
        skills_root=skills,
        agent_dir=agents,
        skills_prefix="C:\\Users\\Test\\.codex\\skills\\",
        launcher=rewrite.windows_launcher_command(
            r"C:\Program Files\Python312\python.exe",
            [],
            r"C:\Users\Test\.codex\skills\seo\scripts\runtime.py",
        ),
    )
    launcher = "& 'C:/Program Files/Python312/python.exe' 'C:/Users/Test/.codex/skills/seo/scripts/runtime.py'"
    touched = 0
    for path in paths:
        text = path.read_text(encoding="utf-8")
        tomllib.loads(text)
        original = originals[path.name]
        if "${CODEX_PLUGIN_ROOT}" in original:
            touched += 1
            assert "${CODEX_PLUGIN_ROOT}" not in text
            assert "\\Users" not in text
            assert "\\Program Files" not in text
            if '"${CODEX_PLUGIN_ROOT}/scripts/codex-seo"' in original:
                assert launcher in text
        else:
            assert text == original
    assert touched == changed
    assert touched >= 19


def test_installer_uses_resolved_python_for_the_rewrite() -> None:
    text = (ROOT / "install.ps1").read_text(encoding="utf-8")
    assert "Executable" in text
    assert "--python-exe\", $selectedPython" in text or '--python-exe", $selectedPython' in text
