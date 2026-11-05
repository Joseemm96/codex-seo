"""Regression tests for setup_mcp.py's atomic ~/.codex/config.toml write.

config.toml is shared with other Codex MCP servers, so save_settings() must
never leave it truncated. It stages the write to a temp file in the same
directory and swaps it into place with os.replace.
"""

from __future__ import annotations

import importlib.util
import tomllib
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]


def _load_module(monkeypatch, home: Path):
    """Import setup_mcp.py fresh with HOME pointed at an isolated directory."""
    monkeypatch.setenv("HOME", str(home))
    monkeypatch.setenv("USERPROFILE", str(home))
    monkeypatch.delenv("CODEX_HOME", raising=False)
    spec = importlib.util.spec_from_file_location(
        "banana_setup_mcp", REPO_ROOT / "extensions/banana/scripts/setup_mcp.py"
    )
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _config(home: Path) -> Path:
    return home / ".codex" / "config.toml"


def test_setup_mcp_writes_config_with_no_leftover_temp_file(tmp_path, monkeypatch):
    module = _load_module(monkeypatch, tmp_path)

    module.setup_mcp("dummy-api-key")

    settings_path = _config(tmp_path)
    assert settings_path.exists()
    data = tomllib.loads(settings_path.read_text(encoding="utf-8"))
    assert data["mcp_servers"]["nanobanana-mcp"]["env"]["GOOGLE_AI_API_KEY"] == "dummy-api-key"
    assert list((tmp_path / ".codex").glob(".config.toml.*.tmp")) == []


def test_save_settings_preserves_unrelated_keys_on_existing_file(tmp_path, monkeypatch):
    path = _config(tmp_path)
    path.parent.mkdir(parents=True)
    path.write_text(
        "\n".join(
            [
                '[notes]',
                'keep = "me"',
                "",
                "[mcp_servers.remote]",
                'url = "https://example.test/mcp"',
                'bearer_token_env_var = "TOKEN"',
                "enabled = true",
                "",
                '[mcp_servers."other-mcp"]',
                'command = "x"',
                "",
            ]
        ),
        encoding="utf-8",
    )
    module = _load_module(monkeypatch, tmp_path)

    module.setup_mcp("dummy-api-key")

    text = path.read_text(encoding="utf-8")
    data = tomllib.loads(text)
    assert data["notes"]["keep"] == "me"
    assert data["mcp_servers"]["other-mcp"]["command"] == "x"
    remote = data["mcp_servers"]["remote"]
    assert remote["url"] == "https://example.test/mcp"
    assert remote["bearer_token_env_var"] == "TOKEN"
    assert remote["enabled"] is True
    assert data["mcp_servers"]["nanobanana-mcp"]["env"]["GOOGLE_AI_API_KEY"] == "dummy-api-key"


def test_save_settings_stages_temp_file_in_same_directory(tmp_path, monkeypatch):
    module = _load_module(monkeypatch, tmp_path)
    editor = module._codex_config()
    tmp_dirs_seen = []
    real_mkstemp = editor.tempfile.mkstemp

    def spy_mkstemp(*args, **kwargs):
        fd, path = real_mkstemp(*args, **kwargs)
        tmp_dirs_seen.append(Path(path).parent)
        return fd, path

    monkeypatch.setattr(editor.tempfile, "mkstemp", spy_mkstemp)

    module.save_settings({"mcpServers": {}})

    assert tmp_dirs_seen == [tmp_path / ".codex"]
    assert _config(tmp_path).exists()


def test_save_settings_cleans_up_temp_file_and_leaves_original_on_failure(tmp_path, monkeypatch):
    path = _config(tmp_path)
    path.parent.mkdir(parents=True)
    original = '[notes]\nkeep = "value"\n'
    path.write_text(original, encoding="utf-8")
    module = _load_module(monkeypatch, tmp_path)

    class Unserializable:
        pass

    with pytest.raises(TypeError):
        module.save_settings({"bad": Unserializable()})

    assert path.read_text(encoding="utf-8") == original
    assert list(path.parent.glob(".config.toml.*.tmp")) == []
