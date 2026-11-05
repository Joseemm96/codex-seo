"""MCP agent permission and fail-closed regressions."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AGENTS = (
    ROOT / "agents" / "seo-dataforseo.toml",
    ROOT / "extensions" / "dataforseo" / "agents" / "seo-dataforseo.toml",
)


def _text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_dataforseo_agent_mirrors_allow_only_sanctioned_mcp_path():
    for path in AGENTS:
        text = _text(path)
        tools_line = next(line for line in text.splitlines() if line.startswith("tools =") or line.startswith("tools:"))
        assert "mcp__dataforseo__*" in tools_line
        assert "Bash" not in tools_line


def test_dataforseo_agent_mirrors_fail_closed_without_mcp():
    required = (
        "fail closed",
        "Never inspect credential or",
        "never bypass MCP with curl, raw HTTP, or another client",
    )
    for path in AGENTS:
        text = _text(path)
        for phrase in required:
            assert phrase in text


def test_dataforseo_agent_bodies_stay_mirrored():
    assert _text(AGENTS[0]) == _text(AGENTS[1])


def test_dataforseo_installers_use_matching_mcp_server_name():
    # Both installers pass the server name to codex_config.py. The rendered
    # table is [mcp_servers."dataforseo"], which matches mcp__dataforseo__*.
    assert "--server dataforseo" in _text(ROOT / "extensions/dataforseo/install.sh")
    assert "--server dataforseo" in _text(ROOT / "extensions/dataforseo/install.ps1")
