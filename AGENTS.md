# Codex SEO: Universal SEO Analysis Skill

Codex SEO is a Codex-first SEO analysis skill suite with 28 sub-skills, 25 TOML sub-agents, and 81 Python execution scripts. It is synced from [AgriciDaniel/claude-seo](https://github.com/AgriciDaniel/claude-seo) v2.5.0 (commit `219ff485bb016314bb4c15bfc7978df61c668a4f`) and adapted for Codex. The canonical repository is [Joseemm96/codex-seo](https://github.com/Joseemm96/codex-seo).

The canonical skill tree lives under `skills/`. The main orchestrator is `skills/seo/SKILL.md`.

## Architecture

```text
codex-seo/
  .codex-plugin/plugin.json       # Codex plugin manifest
  skills/seo/SKILL.md             # Main orchestrator and routing
  skills/seo-*/SKILL.md           # Specialist SEO workflows
  skills/seo/references/          # Shared references, cache schemas, thresholds
  agents/seo-*.toml               # Codex specialist agent profiles
  scripts/                        # Deterministic Python runners and the codex-seo launcher
  hooks/                          # Pre-commit schema and SEO checks
  schema/                         # Schema.org JSON-LD templates
  data/                           # Bundled primary-source ledgers
  extensions/                     # Optional MCP and API extension installers
  tests/                          # Contract, manifest, wrapper, and runtime tests
```

## Cross-platform portability

Every skill in `skills/*/SKILL.md` is authored to a portable subset of the skill spec. Validate it with:

```bash
./scripts/codex-seo run portability_check.py
```

Python range for that launcher is 3.11 to 3.14. `scripts/runtime.py` is the source of truth.

### Per-harness notes

| Harness | How to load codex-seo |
|---|---|
| **Cursor** | Symlink or copy `skills/` and `agents/` into the project. Commands are natural-language prompts. The harness reads `SKILL.md` as context. |
| **Cursor Cloud Agents** | Push the repo. Cloud Agents read `AGENTS.md` at session start. |
| **Google Antigravity** | Point the workspace at this repo root. Antigravity reads `AGENTS.md` first. |
| **Gemini CLI** | `gemini init` in this repo loads `AGENTS.md`. |
| **OpenAI Codex CLI** | Reads `AGENTS.md` from the project root. Run bundled tools through `./scripts/codex-seo`. |
| **Cline** | Loads `AGENTS.md` from the project root. Subagent delegation falls back to in-context expansion. |
| **Aider** | Reads `AGENTS.md` when present. Aider does not dispatch sub-agents, so seo-* skills run inline. |

### Tool-name compatibility

Where skills mention `Read`, `Write`, `Edit`, `Bash`, `Glob`, `Grep`, or `WebFetch`, harnesses map them as follows:

| Claude Code | Codex | Cline | Aider | Cursor / Antigravity |
|---|---|---|---|---|
| Read | read_file | read_file | (inline) | read |
| Write | write_file | write_file | /add then edit | write |
| Edit | apply_diff | replace_in_file | /edit | edit |
| Bash | bash | execute_command | /run | shell |
| Glob | glob | search_files | (inline) | find |
| Grep | grep | search_files | /grep | grep |
| WebFetch | fetch / browse | (browser tool) | (n/a) | fetch |

## Development Rules

- Keep `SKILL.md` files under 500 lines.
- Reference files should stay focused and loaded on demand.
- Scripts must have docstrings, CLI help, and JSON output when used by wrappers.
- Follow kebab-case naming for skill directories.
- Python dependencies for `/seo setup` come from `requirements.txt` (Python 3.11 to 3.14).
- The curl installer still bootstraps `~/.codex/skills/seo/.venv` with the JSON status file from codex.5.
- All skills include a shared cache Step 0 and cache write guidance.
- New config paths use `~/.config/codex-seo/` and `~/.cache/codex-seo/`. Legacy `~/.config/claude-seo/` and `~/.cache/claude-seo/` paths are read only when the Codex path is absent.
- Bundled Python tools run through `"${CODEX_PLUGIN_ROOT}/scripts/codex-seo" run <script.py>`.
- MCP extension installers write `[mcp_servers."<name>"]` tables into `$CODEX_HOME/config.toml` (default `~/.codex/config.toml`).
- Run `python -m pytest tests/` after changes.

## Key Principles

1. **Codex-first packaging**: skills, `.toml` agents, and `.codex-plugin/plugin.json`.
2. **Progressive disclosure**: metadata always loaded, references on demand.
3. **Evidence over guesses**: do not fabricate crawl, SERP, API, or performance data.
4. **Cross-skill caching**: `.seo-cache/` enables reuse between workflows.
5. **Deterministic wrappers**: API and headless paths return structured artifacts and setup-required states.
6. **Footer gating**: promotional and community footer is disabled by default unless explicitly enabled.

## Alias skills

`seo-performance` and `seo-visual` stay as thin skill aliases because upstream v2.5.0 ships those workflows as agents only. `seo-firecrawl` is not a core skill folder. It lives in `extensions/firecrawl/` and is installed by that extension. A Codex TOML agent, `agents/seo-firecrawl.toml`, remains so audits can delegate to it after the extension is installed.

## Shipping Rules

Read first, write second, verify third. Keep changes scoped, preserve rollback paths, and verify claims with tests or direct inspection.
