"""Extension installers must not put credential values on the Python command line.

The shared editor in scripts/codex_config.py reads secrets from the environment,
replaces one table, and refuses to overwrite an unparseable config.toml.
"""

from __future__ import annotations

import os
import stat
import subprocess
import sys
import tomllib
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "scripts" / "codex_config.py"
REMOTE = """
[mcp_servers.remote]
url = "https://example.test/mcp"
bearer_token_env_var = "TOKEN"
enabled = true
"""

MCP_CASES = [
    "firecrawl-mcp",
    "dataforseo",
    "nanobanana-mcp",
    "ahrefs",
]
TABLE_CASES = [
    ("codex_seo.profound", "PROFOUND_API_KEY"),
    ("codex_seo.seranking", "SERANKING_API_KEY"),
]


def _mode(path: Path) -> int:
    return stat.S_IMODE(path.stat().st_mode)


def test_shell_installers_delegate_to_the_shared_editor() -> None:
    expected = {
        "extensions/firecrawl/install.sh": "upsert-mcp",
        "extensions/dataforseo/install.sh": "upsert-mcp",
        "extensions/banana/install.sh": "upsert-mcp",
        "extensions/ahrefs/install.sh": "upsert-mcp",
        "extensions/profound/install.sh": "upsert-table",
        "extensions/seranking/install.sh": "upsert-table",
        "extensions/bing-webmaster/install.sh": "store-bing",
    }
    for rel, command in expected.items():
        text = (ROOT / rel).read_text(encoding="utf-8")
        assert "scripts/codex_config.py" in text, rel
        assert command in text, rel
        assert "<<'PY'" not in text, rel
        joined = text.replace("\\\n", " ")
        for line in joined.splitlines():
            if "python3" not in line or "codex_config.py" not in line:
                continue
            args = line.split("python3", 1)[1]
            assert "${CONFIG_HELPER}" in args or "codex_config.py" in args
            assert not any(
                token in args
                for token in (
                    "${FIRECRAWL_API_KEY}",
                    "${DFSE_PASSWORD}",
                    "${DFSE_USERNAME}",
                    "${GOOGLE_AI_API_KEY}",
                    "${AHREFS_TOKEN}",
                    "${PROFOUND_KEY}",
                    "${SR_KEY}",
                    "${BING_KEY}",
                    "${INDEXNOW_KEY}",
                    "${INDEXNOW_LOC}",
                )
            ), (rel, line)


def test_shell_uninstallers_remove_real_tables() -> None:
    expected = {
        "extensions/firecrawl/uninstall.sh": "remove-mcp",
        "extensions/dataforseo/uninstall.sh": "remove-mcp",
        "extensions/banana/uninstall.sh": "remove-mcp",
        "extensions/ahrefs/uninstall.sh": "remove-mcp",
        "extensions/profound/uninstall.sh": "remove-table",
        "extensions/seranking/uninstall.sh": "remove-table",
        "extensions/bing-webmaster/uninstall.sh": "remove-bing",
    }
    for rel, command in expected.items():
        text = (ROOT / rel).read_text(encoding="utf-8")
        assert "codex_config.py" in text, rel
        assert command in text, rel
        assert "json.load" not in text, rel


@pytest.mark.skipif(os.name != "posix", reason="asserts POSIX mode bits")
@pytest.mark.parametrize("server", MCP_CASES)
def test_mcp_upsert_preserves_other_servers_and_stores_secret_literally(tmp_path: Path, server: str) -> None:
    settings = tmp_path / "config.toml"
    settings.write_text(
        f'[mcp_servers.{server}]\ncommand = "old"\n\n{REMOTE}',
        encoding="utf-8",
    )
    payload = "x'''; open('pwned','w').write('pwned'); y='''"
    env = {**os.environ, "CODEX_SEO_SECRET": payload}
    result = subprocess.run(
        [
            sys.executable,
            str(HELPER),
            "upsert-mcp",
            "--path",
            str(settings),
            "--server",
            server,
            "--command",
            "npx",
            "--arg=-y",
            "--env-from",
            "EXAMPLE_KEY=CODEX_SEO_SECRET",
        ],
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr
    data = tomllib.loads(settings.read_text(encoding="utf-8"))
    names = list(data["mcp_servers"])
    assert names.count(server) == 1
    assert data["mcp_servers"][server]["env"]["EXAMPLE_KEY"] == payload
    remote = data["mcp_servers"]["remote"]
    assert remote["url"] == "https://example.test/mcp"
    assert remote["bearer_token_env_var"] == "TOKEN"
    assert remote["enabled"] is True
    assert _mode(settings) == 0o600


@pytest.mark.parametrize("table,field", TABLE_CASES)
def test_table_upsert_replaces_bare_heading_without_duplicating(tmp_path: Path, table: str, field: str) -> None:
    settings = tmp_path / "config.toml"
    bare = table.replace(".", ".")
    settings.write_text(f"[{bare}]\n{field} = \"old\"\n\n[notes]\nkeep = \"yes\"\n", encoding="utf-8")
    env = {**os.environ, "CODEX_SEO_SECRET": 'quote " and \\ slash'}
    result = subprocess.run(
        [
            sys.executable,
            str(HELPER),
            "upsert-table",
            "--path",
            str(settings),
            "--table",
            table,
            "--env-from",
            f"{field}=CODEX_SEO_SECRET",
        ],
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr
    text = settings.read_text(encoding="utf-8")
    data = tomllib.loads(text)
    assert data["notes"]["keep"] == "yes"
    parent, child = table.split(".")
    assert data[parent][child][field] == 'quote " and \\ slash'


@pytest.mark.parametrize("server", MCP_CASES)
def test_upsert_refuses_unparseable_toml(tmp_path: Path, server: str) -> None:
    settings = tmp_path / "config.toml"
    original = '[mcp_servers.mine]\ncommand = "keep"\n oops'
    settings.write_text(original, encoding="utf-8")
    env = {**os.environ, "CODEX_SEO_SECRET": "secret-value"}
    result = subprocess.run(
        [
            sys.executable,
            str(HELPER),
            "upsert-mcp",
            "--path",
            str(settings),
            "--server",
            server,
            "--command",
            "npx",
            "--env-from",
            "EXAMPLE_KEY=CODEX_SEO_SECRET",
        ],
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode != 0
    assert settings.read_text(encoding="utf-8") == original
    assert "Nothing was changed" in result.stderr


def test_ps1_installers_call_the_helper_and_check_exit_code() -> None:
    expected = {
        "extensions/firecrawl/install.ps1": "upsert-mcp",
        "extensions/dataforseo/install.ps1": "upsert-mcp",
        "extensions/ahrefs/install.ps1": "upsert-mcp",
        "extensions/profound/install.ps1": "upsert-table",
        "extensions/seranking/install.ps1": "upsert-table",
        "extensions/bing-webmaster/install.ps1": "store-bing",
    }
    for rel, command in expected.items():
        text = (ROOT / rel).read_text(encoding="utf-8")
        assert "codex_config.py" in text, rel
        assert command in text, rel
        assert "$env:CODEX_SEO_SECRET = " in text, rel
        assert "if ($LASTEXITCODE -ne 0) { throw" in text, rel
        assert "ConvertFrom-Json" not in text, rel
        assert "| python -" not in text, rel


def test_matomo_ps1_still_checks_the_python_exit_code() -> None:
    text = (ROOT / "extensions/matomo/install.ps1").read_text(encoding="utf-8")
    assert "$env:CODEX_SEO_SECRET = " in text
    assert "if ($LASTEXITCODE -ne 0) { throw" in text
