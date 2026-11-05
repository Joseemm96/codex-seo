#!/usr/bin/env python3
"""
Validate that the Claude Banana MCP server is properly configured.

Checks:
1. Claude Code ~/.codex/config.toml has the MCP entry
2. API key is present
3. Node.js/npx is available
4. Output directory exists or can be created

Usage:
    python3 validate_setup.py
"""

import argparse
import os
import shutil
import sys
import tomllib
from pathlib import Path

SETTINGS_PATH = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex")) / "config.toml"
MCP_NAME = "nanobanana-mcp"
OUTPUT_DIR = Path.home() / "Documents" / "nanobanana_generated"


def check(label: str, passed: bool, detail: str = "") -> bool:
    status = "PASS" if passed else "FAIL"
    msg = f"  [{status}] {label}"
    if detail:
        msg += f": {detail}"
    print(msg)
    return passed


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate the Claude Banana MCP server setup."
    )
    return parser.parse_args()


def main() -> int:
    parse_args()

    print("Claude Banana - Setup Validation")
    print("=" * 40)
    results = []

    # 1. Settings file exists
    results.append(check(
        "Claude Code ~/.codex/config.toml exists",
        SETTINGS_PATH.exists(),
        str(SETTINGS_PATH),
    ))

    if not SETTINGS_PATH.exists():
        print("\nCannot continue without ~/.codex/config.toml.")
        return 1

    # 2. Load and parse settings
    try:
        data = tomllib.loads(SETTINGS_PATH.read_text(encoding="utf-8"))
        results.append(check("~/.codex/config.toml is valid TOML", True))
    except tomllib.TOMLDecodeError as e:
        results.append(check("~/.codex/config.toml is valid TOML", False, str(e)))
        return 1

    # 3. MCP entry exists
    raw_servers = data.get("mcp_servers") or {}
    servers = {}
    for name, table in raw_servers.items():
        if isinstance(table, dict):
            servers[name] = {
                "command": table.get("command"),
                "args": list(table.get("args") or []),
                "env": dict(table.get("env") or {}),
            }
    has_mcp = MCP_NAME in servers
    results.append(check(f"MCP server '{MCP_NAME}' configured", has_mcp))

    if has_mcp:
        mcp = servers[MCP_NAME]

        # 4. Command is npx
        results.append(check(
            "Command is 'npx'",
            mcp.get("command") == "npx",
            mcp.get("command", "(missing)"),
        ))

        # 5. Package is correct
        args = mcp.get("args", [])
        has_pkg = "@ycse/nanobanana-mcp" in args
        results.append(check(
            "Package is @ycse/nanobanana-mcp",
            has_pkg,
            str(args),
        ))

        # 6. API key present
        env = mcp.get("env", {})
        key = env.get("GOOGLE_AI_API_KEY", "")
        results.append(check(
            "GOOGLE_AI_API_KEY is set",
            bool(key),
            f"...{key[-4:]}" if len(key) > 12 else "(empty or short)",
        ))

        # 7. Model configured
        model = env.get("NANOBANANA_MODEL", "")
        results.append(check(
            "NANOBANANA_MODEL is set",
            bool(model),
            model or "(not set, will use package default)",
        ))

    # 8. Node.js/npx available
    has_npx = shutil.which("npx") is not None
    results.append(check(
        "npx is available in PATH",
        has_npx,
        shutil.which("npx") or "not found",
    ))

    # 9. Output directory
    if OUTPUT_DIR.exists():
        results.append(check("Output directory exists", True, str(OUTPUT_DIR)))
    else:
        try:
            OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
            results.append(check("Output directory created", True, str(OUTPUT_DIR)))
        except OSError as e:
            results.append(check("Output directory writable", False, str(e)))

    # Summary
    passed = sum(1 for r in results if r)
    total = len(results)
    print(f"\n{'=' * 40}")
    print(f"Results: {passed}/{total} checks passed")

    if passed == total:
        print("Status: Ready to generate images!")
        return 0
    else:
        print("Status: Some checks failed. Fix the issues above.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
