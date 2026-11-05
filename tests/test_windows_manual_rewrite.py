"""Windows manual installs rewrite skills and agents to a real Python command."""

from __future__ import annotations

import sys
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
    assert f"{expected} run fetch_page.py" in skill_text
    assert f"{expected} doctor" in agent_text
    assert r"C:\Users\Vessel\.codex\skills\seo/references/x.md" in skill_text
    assert "${CODEX_PLUGIN_ROOT}" not in skill_text
    assert "${CODEX_PLUGIN_ROOT}" not in agent_text


def test_installer_uses_resolved_python_for_the_rewrite() -> None:
    text = (ROOT / "install.ps1").read_text(encoding="utf-8")
    assert "Executable" in text
    assert "--python-exe\", $selectedPython" in text or '--python-exe", $selectedPython' in text
