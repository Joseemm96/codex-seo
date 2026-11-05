#!/usr/bin/env python3
"""Rewrite manual-install skill and agent instructions for one platform.

Unix installs keep the ``scripts/codex-seo`` launcher. Windows installs have
no plugin-root substitution and no Bash launcher, so ``install.ps1`` calls
this script to replace ``"${CODEX_PLUGIN_ROOT}/scripts/codex-seo"`` with a
PowerShell command: the selected Python executable plus the installed
``runtime.py``. Paths are single-quoted and embedded quotes are doubled.

Usage:
    python3 scripts/rewrite_manual_paths.py --skills-root DIR --agent-dir DIR \\
        --python-exe PYTHON --runtime RUNTIME.py [--python-arg ARG]
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

LAUNCHER_TOKEN = '"${CODEX_PLUGIN_ROOT}/scripts/codex-seo"'
SKILLS_TOKEN = "${CODEX_PLUGIN_ROOT}/skills/"


def powershell_single_quote(value: str) -> str:
    """Quote a PowerShell literal so spaces and quotes stay inside one argument."""
    return "'" + value.replace("'", "''") + "'"


def windows_launcher_command(python_exe: str, python_args: list[str], runtime_py: str) -> str:
    """Build ``& 'python' ['args'] 'runtime.py'`` for installed instructions."""
    parts = [powershell_single_quote(python_exe)]
    parts.extend(powershell_single_quote(arg) for arg in python_args if arg)
    parts.append(powershell_single_quote(runtime_py))
    return "& " + " ".join(parts)


def rewrite_text(text: str, *, skills_prefix: str, launcher: str | None) -> str:
    """Replace plugin-root tokens. ``launcher`` None keeps the Unix shell launcher."""
    updated = text.replace(SKILLS_TOKEN, skills_prefix)
    if launcher:
        updated = updated.replace(LAUNCHER_TOKEN, launcher)
    else:
        # install.sh performs the Unix launcher substitution itself. This
        # branch exists so a caller can rewrite skill paths alone.
        pass
    return updated


def _write_if_changed(path: Path, updated: str) -> bool:
    original = path.read_text(encoding="utf-8")
    if original == updated:
        return False
    with path.open("w", encoding="utf-8", newline="") as handle:
        handle.write(updated)
    return True


def rewrite_tree(
    *,
    skills_root: Path,
    agent_dir: Path | None,
    skills_prefix: str,
    launcher: str | None,
) -> int:
    """Rewrite installed Markdown skills and TOML agents. Return the file count."""
    changed = 0
    if skills_root.is_dir():
        for path in skills_root.rglob("*.md"):
            if not path.is_file():
                continue
            updated = rewrite_text(path.read_text(encoding="utf-8"), skills_prefix=skills_prefix, launcher=launcher)
            if _write_if_changed(path, updated):
                changed += 1
    if agent_dir is not None and agent_dir.is_dir():
        for path in agent_dir.glob("seo-*.toml"):
            updated = rewrite_text(path.read_text(encoding="utf-8"), skills_prefix=skills_prefix, launcher=launcher)
            if _write_if_changed(path, updated):
                changed += 1
    return changed


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Rewrite manual Codex SEO install paths")
    parser.add_argument("--skills-root", type=Path, required=True)
    parser.add_argument("--agent-dir", type=Path)
    parser.add_argument("--skills-prefix", help="Replacement for ${CODEX_PLUGIN_ROOT}/skills/")
    parser.add_argument("--python-exe", help="Selected Python executable for a Windows command")
    parser.add_argument("--python-arg", action="append", default=[], help="Argument that must precede runtime.py")
    parser.add_argument("--runtime", type=Path, help="Installed runtime.py")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    launcher = None
    if args.python_exe or args.runtime:
        if not args.python_exe or args.runtime is None:
            print("Windows rewrite needs both --python-exe and --runtime", file=sys.stderr)
            return 2
        launcher = windows_launcher_command(args.python_exe, list(args.python_arg), str(args.runtime))
    if args.skills_prefix:
        prefix = args.skills_prefix
    else:
        prefix = str(args.skills_root).rstrip("\\/") + "/"
    changed = rewrite_tree(
        skills_root=args.skills_root,
        agent_dir=args.agent_dir,
        skills_prefix=prefix,
        launcher=launcher,
    )
    print(f"Rewrote {changed} installed instruction file(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
