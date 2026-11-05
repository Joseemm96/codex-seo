"""Bing install stores credentials where backlinks_auth and IndexNow read them."""

from __future__ import annotations

import json
import os
import site
import subprocess
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "scripts" / "codex_config.py"
# Credential helpers import requests. Isolating HOME must not hide the
# interpreter's real user site-packages.
_USER_SITE = site.getusersitepackages()


def _env(home: Path, **extra: str) -> dict[str, str]:
    env = os.environ.copy()
    env["HOME"] = str(home)
    env["USERPROFILE"] = str(home)
    env["PYTHONPATH"] = _USER_SITE + os.pathsep + env.get("PYTHONPATH", "")
    env.pop("BING_WEBMASTER_API_KEY", None)
    env.pop("INDEXNOW_KEY", None)
    env.pop("INDEXNOW_KEY_LOCATION", None)
    env.update(extra)
    return env


def test_store_and_remove_bing_credentials(tmp_path: Path) -> None:
    home = tmp_path / "home"
    home.mkdir()
    config = tmp_path / "config.toml"
    config.write_text(
        "\n".join(
            [
                "[codex_seo.bing]",
                'BING_WEBMASTER_API_KEY = "stale"',
                'INDEXNOW_KEY = "stale"',
                "",
                "[mcp_servers.remote]",
                'url = "https://example.test/mcp"',
                'bearer_token_env_var = "TOKEN"',
                "enabled = true",
                "",
            ]
        ),
        encoding="utf-8",
    )
    backlinks = home / ".config" / "codex-seo" / "backlinks-api.json"
    backlinks.parent.mkdir(parents=True)
    backlinks.write_text(json.dumps({"moz_api_key": "moz-keep", "bing_api_key": "old"}), encoding="utf-8")
    key = "bing-dummy-key"
    index_key = "k" * 32
    location = "https://example.com/" + index_key + ".txt"
    stored = subprocess.run(
        [sys.executable, str(HELPER), "store-bing", "--path", str(config)],
        env=_env(
            home,
            CODEX_SEO_SECRET=key,
            CODEX_SEO_INDEXNOW_KEY=index_key,
            CODEX_SEO_INDEXNOW_LOCATION=location,
        ),
        capture_output=True,
        text=True,
        check=False,
    )
    assert stored.returncode == 0, stored.stderr
    data = tomllib.loads(config.read_text(encoding="utf-8"))
    assert "codex_seo" not in data or "bing" not in data.get("codex_seo", {})
    assert data["mcp_servers"]["remote"]["bearer_token_env_var"] == "TOKEN"
    saved = json.loads(backlinks.read_text(encoding="utf-8"))
    assert saved["bing_api_key"] == key
    assert saved["moz_api_key"] == "moz-keep"
    index_path = home / ".config" / "codex-seo" / "indexnow.json"
    assert json.loads(index_path.read_text(encoding="utf-8"))["indexnow_key"] == index_key

    visible = subprocess.run(
        [sys.executable, "-c", "import backlinks_auth,indexnow_submit,json,sys; print(json.dumps({'bing': backlinks_auth.get_bing_api_key(), 'indexnow': indexnow_submit.load_credentials()}))"],
        cwd=str(ROOT / "scripts"),
        env=_env(home),
        capture_output=True,
        text=True,
        check=False,
    )
    assert visible.returncode == 0, visible.stderr
    payload = json.loads(visible.stdout)
    assert payload["bing"] == key
    assert payload["indexnow"]["key"] == index_key
    assert payload["indexnow"]["key_location"] == location

    removed = subprocess.run(
        [sys.executable, str(HELPER), "remove-bing", "--path", str(config)],
        env=_env(home),
        capture_output=True,
        text=True,
        check=False,
    )
    assert removed.returncode == 0, removed.stderr
    after = json.loads(backlinks.read_text(encoding="utf-8"))
    assert "bing_api_key" not in after
    assert after["moz_api_key"] == "moz-keep"
    assert not index_path.exists()
    still = tomllib.loads(config.read_text(encoding="utf-8"))
    assert still["mcp_servers"]["remote"]["url"] == "https://example.test/mcp"


def test_dataforseo_uninstall_removes_only_its_server(tmp_path: Path) -> None:
    codex = tmp_path / ".codex"
    codex.mkdir()
    config = codex / "config.toml"
    config.write_text(
        "\n".join(
            [
                "[mcp_servers.dataforseo]",
                'command = "npx"',
                "",
                "[mcp_servers.dataforseo.env]",
                'DATAFORSEO_PASSWORD = "dummy"',
                "",
                "[mcp_servers.remote]",
                'url = "https://example.test/mcp"',
                'bearer_token_env_var = "TOKEN"',
                "enabled = true",
                "",
            ]
        ),
        encoding="utf-8",
    )
    env = _env(tmp_path, CODEX_HOME=str(codex))
    result = subprocess.run(
        ["bash", str(ROOT / "extensions/dataforseo/uninstall.sh")],
        cwd=ROOT,
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr + result.stdout
    assert "uninstalled" in result.stdout.lower()
    data = tomllib.loads(config.read_text(encoding="utf-8"))
    assert "dataforseo" not in data["mcp_servers"]
    assert data["mcp_servers"]["remote"]["bearer_token_env_var"] == "TOKEN"


def test_uninstall_does_not_claim_success_when_config_is_invalid(tmp_path: Path) -> None:
    codex = tmp_path / ".codex"
    codex.mkdir()
    config = codex / "config.toml"
    original = "[mcp_servers.dataforseo]\ncommand = \"npx\"\n oops\n"
    config.write_text(original, encoding="utf-8")
    result = subprocess.run(
        ["bash", str(ROOT / "extensions/dataforseo/uninstall.sh")],
        cwd=ROOT,
        env=_env(tmp_path, CODEX_HOME=str(codex)),
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode != 0
    assert "uninstalled" not in result.stdout.lower()
    assert config.read_text(encoding="utf-8") == original
