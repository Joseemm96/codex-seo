#!/usr/bin/env python3
"""Safe edits for Codex ``config.toml`` and extension credential files.

Installers and uninstallers call this module instead of copying TOML
rewrites. A change touches one MCP server or one dotted table, leaves every
other table and field in place, and replaces the file only after
``tomllib.loads`` accepts the full proposed document.

Usage:
    python3 scripts/codex_config.py upsert-mcp --path CONFIG --server NAME \\
        --command npx --arg=-y --arg=pkg --env-from FIRECRAWL_API_KEY=CODEX_SEO_SECRET
    python3 scripts/codex_config.py remove-mcp --path CONFIG --server NAME
    python3 scripts/codex_config.py has-mcp --path CONFIG --server NAME
    python3 scripts/codex_config.py upsert-table --path CONFIG --table codex_seo.profound \\
        --env-from PROFOUND_API_KEY=CODEX_SEO_SECRET
    python3 scripts/codex_config.py remove-table --path CONFIG --table codex_seo.profound
    python3 scripts/codex_config.py store-bing --path CONFIG
    python3 scripts/codex_config.py remove-bing --path CONFIG
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import tempfile
import tomllib
from pathlib import Path


class ConfigEditError(RuntimeError):
    """A config edit was refused. The destination file is unchanged."""


def toml_escape(value: str) -> str:
    """Escape a string for a TOML basic string."""
    return (
        str(value)
        .replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\r", "\\r")
        .replace("\n", "\\n")
        .replace("\t", "\\t")
    )


def _key_atom(name: str) -> str:
    escaped = re.escape(name)
    return rf'(?:"{escaped}"|\'{escaped}\'|{escaped})'


def _dotted_head(table: str) -> str:
    parts = table.split(".")
    if not parts or any(not part for part in parts):
        raise ConfigEditError(f"invalid TOML table name: {table}")
    return r"[ \t]*\.[ \t]*".join(_key_atom(part) for part in parts)


def drop_headed_tables(text: str, table: str) -> str:
    """Remove ``[table]`` and child tables in quoted or bare form."""
    head = _dotted_head(table)
    pattern = re.compile(
        rf"(?ms)^[ \t]*\[[ \t]*{head}(?=[ \t]*(?:\]|\.[ \t]*))[^\n]*\n.*?(?=^[ \t]*\[|\Z)"
    )
    return pattern.sub("", text)


def _normalize_header(header: str) -> str:
    parts: list[str] = []
    for raw in header.split("."):
        part = raw.strip()
        if len(part) >= 2 and part[0] == part[-1] and part[0] in {'"', "'"}:
            part = part[1:-1]
        parts.append(part)
    return ".".join(parts)


def _assignment_match(line: str, key: str) -> re.Match[str] | None:
    return re.match(
        rf"""^[ \t]*(?:"{re.escape(key)}"|'{re.escape(key)}'|{re.escape(key)})[ \t]*=[ \t]*(.*)$""",
        line,
    )


def drop_inline_key(text: str, parent: str, key: str) -> str:
    """Remove one assignment directly inside ``[parent]``, including a multiline inline table."""
    lines = text.splitlines(keepends=True)
    kept: list[str] = []
    current = ""
    skipping = False
    depth = 0
    header_re = re.compile(r"^[ \t]*\[([^\]\n]+)\][ \t]*(?:#.*)?(?:\r?\n)?$")
    for line in lines:
        if skipping:
            depth += line.count("{") - line.count("}")
            if depth <= 0:
                skipping = False
            continue
        header = header_re.match(line)
        if header:
            current = _normalize_header(header.group(1))
            kept.append(line)
            continue
        assignment = _assignment_match(line.rstrip("\r\n"), key) if current == parent else None
        if assignment:
            value = assignment.group(1)
            depth = value.count("{") - value.count("}")
            if depth > 0:
                skipping = True
            continue
        kept.append(line)
    return "".join(kept)


def drop_mcp_server(text: str, server: str) -> str:
    """Remove one MCP server whether it is a heading, a child table, or an inline key."""
    text = drop_headed_tables(text, f"mcp_servers.{server}")
    return drop_inline_key(text, "mcp_servers", server)


def render_mcp_server(server: str, command: str, args: list[str], env: dict[str, str]) -> str:
    """Render the quoted MCP server tables installers append."""
    if not isinstance(args, list) or not all(isinstance(item, str) for item in args):
        raise ConfigEditError("MCP args must be strings")
    if not isinstance(env, dict) or not all(isinstance(key, str) and isinstance(value, str) for key, value in env.items()):
        raise ConfigEditError("MCP env values must be strings")
    for key in env:
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
            raise ConfigEditError(f"unsupported env key: {key}")
    arg_text = ", ".join(f'"{toml_escape(item)}"' for item in args)
    lines = [
        f'[mcp_servers."{toml_escape(server)}"]',
        f'command = "{toml_escape(command)}"',
        f"args = [{arg_text}]",
    ]
    if env:
        lines.append("")
        lines.append(f'[mcp_servers."{toml_escape(server)}".env]')
        for key, value in env.items():
            lines.append(f'{key} = "{toml_escape(value)}"')
    return "\n".join(lines) + "\n"


def render_table(table: str, fields: dict[str, str]) -> str:
    """Render one dotted table of string fields."""
    _dotted_head(table)
    lines = [f"[{table}]"]
    for key, value in fields.items():
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
            raise ConfigEditError(f"unsupported field name: {key}")
        if not isinstance(value, str):
            raise ConfigEditError(f"{key} must be a string")
        lines.append(f'{key} = "{toml_escape(value)}"')
    return "\n".join(lines) + "\n"


def _read_toml(path: Path) -> str:
    if not path.exists() or path.stat().st_size == 0:
        return ""
    text = path.read_text(encoding="utf-8")
    try:
        tomllib.loads(text)
    except tomllib.TOMLDecodeError as exc:
        raise ConfigEditError(
            f"{path} is not valid TOML. Nothing was changed; fix it and rerun. ({exc})"
        ) from exc
    return text


def atomic_write_toml(path: Path, text: str) -> None:
    """Validate ``text`` and replace ``path`` without leaving a partial file."""
    payload = text if text.endswith("\n") or text == "" else text + "\n"
    if payload.strip():
        try:
            tomllib.loads(payload)
        except tomllib.TOMLDecodeError as exc:
            raise ConfigEditError(
                f"refusing to write invalid TOML to {path}. Nothing was changed. ({exc})"
            ) from exc
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(prefix=".config.toml.", suffix=".tmp", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(payload if payload else "\n")
        os.chmod(tmp_path, 0o600)
        os.replace(tmp_path, path)
    except BaseException:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise


def _join_block(existing: str, block: str) -> str:
    kept = existing.rstrip()
    if not kept:
        return block
    return kept + "\n\n" + block


def upsert_mcp_server(path: Path, server: str, command: str, args: list[str], env: dict[str, str]) -> None:
    """Replace one MCP server definition and preserve every other server field."""
    existing = _read_toml(path) if path.exists() else ""
    proposed = _join_block(drop_mcp_server(existing, server), render_mcp_server(server, command, args, env))
    atomic_write_toml(path, proposed)


def remove_mcp_server(path: Path, server: str) -> bool:
    """Remove one MCP server. Return True when the file changed."""
    if not path.exists():
        return False
    existing = _read_toml(path)
    proposed = drop_mcp_server(existing, server).rstrip() + ("\n" if existing.strip() else "")
    if proposed == existing or proposed.strip() == existing.strip():
        return False
    atomic_write_toml(path, proposed)
    return True


def mcp_server_exists(path: Path, server: str) -> bool:
    """Return whether ``server`` is declared in ``path``."""
    if not path.exists() or path.stat().st_size == 0:
        return False
    data = tomllib.loads(_read_toml(path))
    servers = data.get("mcp_servers") or {}
    return isinstance(servers, dict) and server in servers


def upsert_table(path: Path, table: str, fields: dict[str, str]) -> None:
    """Replace one dotted table and preserve the rest of the document."""
    existing = _read_toml(path) if path.exists() else ""
    proposed = _join_block(drop_headed_tables(existing, table), render_table(table, fields))
    atomic_write_toml(path, proposed)


def remove_table(path: Path, table: str) -> bool:
    """Remove one dotted table. Return True when the file changed."""
    if not path.exists():
        return False
    existing = _read_toml(path)
    proposed = drop_headed_tables(existing, table)
    if proposed == existing:
        return False
    atomic_write_toml(path, proposed.rstrip() + "\n")
    return True


def _env_map(pairs: list[str]) -> dict[str, str]:
    mapped: dict[str, str] = {}
    for pair in pairs:
        if "=" not in pair:
            raise ConfigEditError(f"expected DEST=SOURCE_ENV, got {pair}")
        dest, source = pair.split("=", 1)
        if source not in os.environ:
            raise ConfigEditError(f"environment variable {source} is not set")
        value = os.environ[source]
        if value == "":
            raise ConfigEditError(f"environment variable {source} is empty")
        mapped[dest] = value
    return mapped


def _literal_map(pairs: list[str]) -> dict[str, str]:
    mapped: dict[str, str] = {}
    for pair in pairs:
        if "=" not in pair:
            raise ConfigEditError(f"expected KEY=VALUE, got {pair}")
        key, value = pair.split("=", 1)
        mapped[key] = value
    return mapped


def _prefer_config_file(name: str) -> Path:
    """Match the tools: Codex path, unless only the legacy claude-seo file exists."""
    primary = Path.home() / ".config" / "codex-seo" / name
    legacy = Path.home() / ".config" / "claude-seo" / name
    if primary.exists() or not legacy.exists():
        return primary
    return legacy


def _read_json_object(path: Path) -> dict:
    try:
        loaded = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ConfigEditError(f"could not read {path}: {exc}") from exc
    if not isinstance(loaded, dict):
        raise ConfigEditError(f"{path} is not a JSON object")
    return loaded


def _write_secure_json(path: Path, data: dict) -> None:
    """Write JSON as mode 0600 without importing the analysis packages."""
    path.parent.mkdir(parents=True, exist_ok=True)
    flags = os.O_WRONLY | os.O_CREAT | os.O_TRUNC
    fd = os.open(path, flags, 0o600)
    try:
        if hasattr(os, "fchmod"):
            try:
                os.fchmod(fd, 0o600)
            except OSError:
                pass
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(data, handle, indent=2)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
    except BaseException:
        try:
            os.close(fd)
        except OSError:
            pass
        raise
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass


def _try_load_tool(name: str):
    """Import a script when its dependencies exist. Installers must work without them."""
    scripts = str(Path(__file__).resolve().parent)
    if scripts not in sys.path:
        sys.path.insert(0, scripts)
    try:
        return __import__(name)
    except (ImportError, ModuleNotFoundError, RuntimeError):
        return None


def store_bing_credentials(config_path: Path | None) -> None:
    """Write Bing and IndexNow credentials where the tools read them.

    The Bing key is merged into the backlink credential file. IndexNow uses
    its own credential file. A legacy ``[codex_seo.bing]`` table is removed
    when ``config_path`` exists so plaintext keys do not remain there.
    """
    bing = os.environ.get("CODEX_SEO_SECRET", "")
    idx_key = os.environ.get("CODEX_SEO_INDEXNOW_KEY", "")
    idx_loc = os.environ.get("CODEX_SEO_INDEXNOW_LOCATION", "")
    if not bing and not idx_key and not idx_loc:
        raise ConfigEditError("provide a Bing API key, an IndexNow key, or both")
    if config_path is not None and config_path.exists():
        remove_table(config_path, "codex_seo.bing")
    if bing:
        raw_path = _prefer_config_file("backlinks-api.json")
        existing = _read_json_object(raw_path) if raw_path.exists() else {}
        existing["bing_api_key"] = bing
        _write_secure_json(raw_path, existing)
        saved = _read_json_object(raw_path)
        if saved.get("bing_api_key") != bing:
            raise ConfigEditError("Bing key was not visible in the backlink credential file after save")
        backlinks = _try_load_tool("backlinks_auth")
        if backlinks is not None and backlinks.get_bing_api_key() != bing:
            raise ConfigEditError("backlinks_auth did not return the saved Bing key")
    if idx_key or idx_loc:
        index_path = Path.home() / ".config" / "codex-seo" / "indexnow.json"
        current: dict[str, str] = {}
        if index_path.exists():
            loaded = _read_json_object(index_path)
            for source, dest in (("indexnow_key", "indexnow_key"), ("indexnow_key_location", "indexnow_key_location")):
                value = loaded.get(source)
                if isinstance(value, str) and value:
                    current[dest] = value
        if idx_key:
            current["indexnow_key"] = idx_key
        if idx_loc:
            current["indexnow_key_location"] = idx_loc
        _write_secure_json(index_path, current)
        saved_index = _read_json_object(index_path)
        if idx_key and saved_index.get("indexnow_key") != idx_key:
            raise ConfigEditError("IndexNow key was not visible after save")
        if idx_loc and saved_index.get("indexnow_key_location") != idx_loc:
            raise ConfigEditError("IndexNow key location was not visible after save")
        indexnow = _try_load_tool("indexnow_submit")
        if indexnow is not None:
            stored = indexnow.load_credentials()
            if idx_key and stored.get("key") != idx_key:
                raise ConfigEditError("indexnow_submit did not return the saved key")
            if idx_loc and stored.get("key_location") != idx_loc:
                raise ConfigEditError("indexnow_submit did not return the saved key location")


def remove_bing_credentials(config_path: Path | None) -> None:
    """Remove Bing and IndexNow credentials without deleting shared backlink keys."""
    raw_path = _prefer_config_file("backlinks-api.json")
    if raw_path.exists():
        loaded = _read_json_object(raw_path)
        loaded.pop("bing_api_key", None)
        _write_secure_json(raw_path, loaded)
        if "bing_api_key" in _read_json_object(raw_path):
            raise ConfigEditError("Bing key is still present in the backlink credential file")
    for index_path in (
        Path.home() / ".config" / "codex-seo" / "indexnow.json",
        Path.home() / ".config" / "claude-seo" / "indexnow.json",
    ):
        try:
            index_path.unlink()
        except FileNotFoundError:
            continue
    codex_index = Path.home() / ".config" / "codex-seo" / "indexnow.json"
    if codex_index.exists():
        raise ConfigEditError("IndexNow credential file is still present")
    if config_path is not None and config_path.exists():
        remove_table(config_path, "codex_seo.bing")
        text = config_path.read_text(encoding="utf-8")
        if text.strip():
            data = tomllib.loads(text)
            bing_table = data.get("codex_seo") if isinstance(data.get("codex_seo"), dict) else {}
            if isinstance(bing_table, dict) and "bing" in bing_table:
                raise ConfigEditError("codex_seo.bing is still present")


def _path_arg(value: str) -> Path:
    return Path(value).expanduser()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Edit Codex config.toml without clobbering unrelated tables")
    sub = parser.add_subparsers(dest="action", required=True)

    upsert = sub.add_parser("upsert-mcp", help="replace one mcp_servers table")
    upsert.add_argument("--path", type=_path_arg, required=True)
    upsert.add_argument("--server", required=True)
    upsert.add_argument("--command", required=True)
    upsert.add_argument("--arg", action="append", default=[])
    upsert.add_argument("--env-from", action="append", default=[], help="DEST=SOURCE_ENV")
    upsert.add_argument("--set", dest="literals", action="append", default=[], help="KEY=VALUE")

    remove = sub.add_parser("remove-mcp", help="remove one mcp_servers table")
    remove.add_argument("--path", type=_path_arg, required=True)
    remove.add_argument("--server", required=True)

    has = sub.add_parser("has-mcp", help="exit 0 when an MCP server is configured")
    has.add_argument("--path", type=_path_arg, required=True)
    has.add_argument("--server", required=True)

    upsert_tbl = sub.add_parser("upsert-table", help="replace one dotted table")
    upsert_tbl.add_argument("--path", type=_path_arg, required=True)
    upsert_tbl.add_argument("--table", required=True)
    upsert_tbl.add_argument("--env-from", action="append", default=[])
    upsert_tbl.add_argument("--set", dest="literals", action="append", default=[])

    remove_tbl = sub.add_parser("remove-table", help="remove one dotted table")
    remove_tbl.add_argument("--path", type=_path_arg, required=True)
    remove_tbl.add_argument("--table", required=True)

    store = sub.add_parser("store-bing", help="store Bing and IndexNow credentials for the tools that read them")
    store.add_argument("--path", type=_path_arg, required=True, help="Codex config.toml, used only to drop a legacy table")

    clear = sub.add_parser("remove-bing", help="remove Bing and IndexNow credentials")
    clear.add_argument("--path", type=_path_arg, required=True)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        if args.action == "upsert-mcp":
            env = {**_literal_map(args.literals), **_env_map(args.env_from)}
            upsert_mcp_server(args.path, args.server, args.command, list(args.arg), env)
            print(f"Configured MCP server {args.server}")
            return 0
        if args.action == "remove-mcp":
            changed = remove_mcp_server(args.path, args.server)
            print(f"Removed MCP server {args.server}" if changed else f"No {args.server} MCP server to remove")
            return 0
        if args.action == "has-mcp":
            return 0 if mcp_server_exists(args.path, args.server) else 1
        if args.action == "upsert-table":
            fields = {**_literal_map(args.literals), **_env_map(args.env_from)}
            if not fields:
                raise ConfigEditError("upsert-table needs at least one field")
            upsert_table(args.path, args.table, fields)
            print(f"Configured {args.table}")
            return 0
        if args.action == "remove-table":
            changed = remove_table(args.path, args.table)
            print(f"Removed {args.table}" if changed else f"No {args.table} table to remove")
            return 0
        if args.action == "store-bing":
            store_bing_credentials(args.path)
            print("Stored Bing and IndexNow credentials")
            return 0
        if args.action == "remove-bing":
            remove_bing_credentials(args.path)
            print("Removed Bing and IndexNow credentials")
            return 0
    except ConfigEditError as exc:
        print(f"x {exc}", file=sys.stderr)
        return 1
    raise ConfigEditError(f"unknown command: {args.action}")


if __name__ == "__main__":
    raise SystemExit(main())
