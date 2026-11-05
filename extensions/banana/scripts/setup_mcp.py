#!/usr/bin/env python3
"""
Setup script for Claude Banana MCP server in Claude Code.

Configures @ycse/nanobanana-mcp in Claude Code's ~/.codex/config.toml
with the user's Google AI API key.

Usage:
    python3 setup_mcp.py                    # Interactive (prompts for key)
    python3 setup_mcp.py --key YOUR_KEY     # Non-interactive
    python3 setup_mcp.py --check            # Verify existing setup
    python3 setup_mcp.py --remove           # Remove MCP config
    python3 setup_mcp.py --help             # Show usage
"""

import importlib.util
import os
import sys
import tomllib
from pathlib import Path

SETTINGS_PATH = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex")) / "config.toml"
MCP_NAME = "nanobanana-mcp"
MCP_PACKAGE = "@ycse/nanobanana-mcp@1.1.1"


_EDITOR = None


def _codex_config():
    global _EDITOR
    if _EDITOR is None:
        _EDITOR = _load_codex_config()
    return _EDITOR


def _load_codex_config():
    """Import the shared config editor from the repo or an installed skill tree."""
    candidates = []
    here = Path(__file__).resolve()
    candidates.append(here.parents[3] / "scripts" / "codex_config.py")
    candidates.append(here.parents[2] / "seo" / "scripts" / "codex_config.py")
    plugin_root = os.environ.get("CODEX_PLUGIN_ROOT")
    if plugin_root:
        candidates.append(Path(plugin_root) / "scripts" / "codex_config.py")
    for path in candidates:
        if path.is_file():
            spec = importlib.util.spec_from_file_location("codex_config", path)
            if spec is None or spec.loader is None:
                continue
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            return module
    raise RuntimeError("codex_config.py was not found. Reinstall Codex SEO.")


def load_settings() -> dict:
    """Load Codex config.toml MCP servers into the dict shape callers expect."""
    if not SETTINGS_PATH.exists():
        return {}
    text = SETTINGS_PATH.read_text(encoding="utf-8")
    if not text.strip():
        return {"mcpServers": {}}
    data = tomllib.loads(text)
    servers = {}
    for name, table in (data.get("mcp_servers") or {}).items():
        if isinstance(table, dict):
            servers[name] = {
                "command": table.get("command"),
                "args": list(table.get("args") or []),
                "env": dict(table.get("env") or {}),
            }
    return {"mcpServers": servers}


def _validate_server(spec: object) -> tuple[str, list[str], dict[str, str]]:
    if not isinstance(spec, dict):
        raise TypeError(f"MCP server {MCP_NAME} must be a dict")
    args = spec.get("args") or []
    env = spec.get("env") or {}
    if not isinstance(args, list) or not isinstance(env, dict):
        raise TypeError(f"MCP server {MCP_NAME} has an unsupported shape")
    if not all(isinstance(item, str) for item in args):
        raise TypeError("MCP args must be strings")
    if not all(isinstance(key, str) and isinstance(value, str) for key, value in env.items()):
        raise TypeError("MCP env values must be strings")
    command = spec.get("command") or ""
    if not isinstance(command, str):
        raise TypeError("MCP command must be a string")
    return command, list(args), dict(env)


def save_settings(settings: dict) -> None:
    """Update only the nanobanana-mcp table, preserving every other server field."""
    if not isinstance(settings, dict) or "mcpServers" not in settings:
        raise TypeError("settings must include mcpServers")
    servers = settings["mcpServers"]
    if not isinstance(servers, dict):
        raise TypeError("mcpServers must be a dict")
    editor = _codex_config()
    if MCP_NAME in servers:
        command, args, env = _validate_server(servers[MCP_NAME])
        editor.upsert_mcp_server(SETTINGS_PATH, MCP_NAME, command, args, env)
    else:
        editor.remove_mcp_server(SETTINGS_PATH, MCP_NAME)
        if not SETTINGS_PATH.exists():
            editor.atomic_write_toml(SETTINGS_PATH, "\n")
    print(f"Settings saved to {SETTINGS_PATH}")


def check_setup() -> bool:
    """Check if MCP is already configured."""
    settings = load_settings()
    servers = settings.get("mcpServers", {})
    if MCP_NAME in servers:
        env = servers[MCP_NAME].get("env", {})
        key = env.get("GOOGLE_AI_API_KEY", "")
        masked = "..." + key[-4:] if len(key) > 12 else "(not set)"
        print(f"MCP server '{MCP_NAME}' is configured.")
        print(f"  Package: {MCP_PACKAGE}")
        print(f"  API Key: {masked}")
        model = env.get("NANOBANANA_MODEL")
        print(f"  Model:   {model if model else 'MCP package default'}")
        return True
    print(f"MCP server '{MCP_NAME}' is NOT configured.")
    return False


def remove_mcp() -> None:
    """Remove MCP configuration."""
    settings = load_settings()
    servers = settings.get("mcpServers", {})
    if MCP_NAME in servers:
        del servers[MCP_NAME]
        settings["mcpServers"] = servers
        save_settings(settings)
        print(f"Removed '{MCP_NAME}' from Claude Code settings.")
    else:
        print(f"'{MCP_NAME}' not found in settings.")


def setup_mcp(api_key: str) -> None:
    """Configure MCP server in Claude Code settings."""
    if not api_key or not api_key.strip():
        print("Error: API key cannot be empty.")
        sys.exit(1)

    api_key = api_key.strip()
    settings = load_settings()

    if "mcpServers" not in settings:
        settings["mcpServers"] = {}

    settings["mcpServers"][MCP_NAME] = {
        "command": "npx",
        "args": ["-y", MCP_PACKAGE],
        "env": {
            "GOOGLE_AI_API_KEY": api_key,
        },
    }

    save_settings(settings)
    print(f"\nMCP server '{MCP_NAME}' configured successfully!")
    print(f"  Package: {MCP_PACKAGE}")
    print("  Model:   MCP package default")
    print("\nRestart Claude Code for changes to take effect.")
    print("Generated images will be saved to: ~/Documents/nanobanana_generated/")


def main() -> None:
    args = sys.argv[1:]

    if "--help" in args or "-h" in args:
        print("Usage: python3 setup_mcp.py [OPTIONS]")
        print()
        print("Options:")
        print("  --key KEY        Provide API key non-interactively")
        print("  --check          Verify existing setup")
        print("  --remove         Remove MCP configuration")
        print("  --help, -h       Show this help message")
        print()
        print("Get a free API key at: https://aistudio.google.com/apikey")
        sys.exit(0)

    if "--check" in args:
        check_setup()
        return

    if "--remove" in args:
        remove_mcp()
        return

    # Get API key
    api_key = None
    for i, arg in enumerate(args):
        if arg == "--key" and i + 1 < len(args):
            api_key = args[i + 1]
            break

    if not api_key:
        # Check environment
        api_key = os.environ.get("GOOGLE_AI_API_KEY")

    if not api_key:
        print("Claude Banana - MCP Setup")
        print("=" * 40)
        print("\nGet your free API key at: https://aistudio.google.com/apikey")
        print()
        try:
            api_key = input("Enter your Google AI API key: ")
        except (EOFError, KeyboardInterrupt):
            print("\nError: No input received. Provide a key with --key or set GOOGLE_AI_API_KEY env var.")
            sys.exit(1)

    setup_mcp(api_key)


if __name__ == "__main__":
    main()
