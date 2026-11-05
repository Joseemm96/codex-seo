"""PowerShell extension installers delegate config.toml edits to codex_config.py.

The previous ConvertTo-Json merge wrote JSON into a TOML file and could not
preserve unrelated MCP fields. Atomic validation now lives in the shared editor.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

INSTALLERS = (
    "extensions/firecrawl/install.ps1",
    "extensions/dataforseo/install.ps1",
    "extensions/ahrefs/install.ps1",
)
UNINSTALLERS = (
    "extensions/firecrawl/uninstall.ps1",
    "extensions/dataforseo/uninstall.ps1",
)


def test_ps1_mcp_installers_use_the_shared_toml_editor() -> None:
    for rel in INSTALLERS:
        text = (ROOT / rel).read_text(encoding="utf-8")
        assert "codex_config.py" in text, rel
        assert "upsert-mcp" in text, rel
        assert "ConvertTo-Json" not in text, rel
        assert "if ($LASTEXITCODE -ne 0) { throw" in text, rel


def test_ps1_mcp_uninstallers_fail_when_removal_fails() -> None:
    for rel in UNINSTALLERS:
        text = (ROOT / rel).read_text(encoding="utf-8")
        assert "codex_config.py" in text, rel
        assert "remove-mcp" in text, rel
        assert "ConvertTo-Json" not in text, rel
        assert "if ($LASTEXITCODE -ne 0) { throw" in text, rel


def test_ahrefs_install_ps1_uses_python_for_the_toml_editor() -> None:
    text = (ROOT / "extensions/ahrefs/install.ps1").read_text(encoding="utf-8")
    assert 'throw "Python 3 required."' in text
    assert "--server ahrefs" in text
