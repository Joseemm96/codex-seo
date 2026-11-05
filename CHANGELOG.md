# Changelog

## [Unreleased]

### Fixed

- Extension installers edit one `mcp_servers` table at a time, including bare and quoted headings, and validate the full `config.toml` before replacing it.
- `bootstrap_environment.py` writes the same `runtime-state.json` the launcher requires, so a successful install can run bundled scripts.
- Installer default ref is `main`. `v2.5.0-codex.1` was never published.
- Windows manual installs rewrite skill and agent launcher commands to the selected Python plus `runtime.py`.
- Bing Webmaster credentials are stored for `backlinks_auth.py` and `indexnow_submit.py`. Uninstall removes those credentials.
- Headless MCP detection reads `config.toml`.
- The plugin manifest no longer declares an unsupported `pre-commit` hook. Use `hooks/install-git-hook.sh` for Git validation.

## [2.5.0+codex.1] - 2026-11-05

### Added

- Re-ported Codex SEO onto `AgriciDaniel/claude-seo` v2.5.0 (`219ff485bb016314bb4c15bfc7978df61c668a4f`, released 2026-10-22). Histories are unrelated, so this is a fresh port rather than a merge.
- Brought over upstream `scripts/`, `skills/` (including `seo-agentic` and `seo-content-brief`), `extensions/` (Ahrefs, Bing Webmaster, Matomo, Profound, SE Ranking, Unlighthouse, plus updated DataForSEO, Firecrawl, and Banana), `schema/`, `data/`, and the v2.5.0 test suite.
- Wired `seo-agentic` and `seo-content-brief` into `skills/seo/SKILL.md` and `.codex-plugin/plugin.json`.
- Added Codex TOML profiles for every upstream agent, including `agents/seo-agentic.toml`.
- Kept thin skill aliases for `seo-performance` and `seo-visual`, which upstream ships as agents without skill folders.
- Added `hooks/pre-commit-schema-check.sh` as the Codex runner for `hooks/validate-schema.py`.

### Changed

- Version is `2.5.0+codex.1`. Installer default ref is `v2.5.0-codex.1`.
- Canonical repository is `https://github.com/Joseemm96/codex-seo`. Upstream attribution stays with `AgriciDaniel/claude-seo`.
- Plugin manifest remains `.codex-plugin/plugin.json`. Project instructions remain `AGENTS.md`.
- Agents are `agents/*.toml`. Extension agent mirrors for DataForSEO and image generation match the core TOML files.
- Launcher and env names are `scripts/codex-seo` and `CODEX_SEO_*` / `CODEX_PLUGIN_ROOT`. `CLAUDE_SEO_PYTHON` is still accepted as a fallback when `CODEX_SEO_PYTHON` is unset.
- Credential and cache reads prefer `~/.config/codex-seo/` and `~/.cache/codex-seo/`, and fall back to the legacy `claude-seo` directories when only those exist.
- MCP extension installers write Codex `config.toml` (`[mcp_servers."<name>"]`) under `$CODEX_HOME` (default `~/.codex`). API-key extensions that are not MCP servers write a `[codex_seo.<name>]` table in that same file. Matomo credentials stay in `~/.config/codex-seo/matomo.json`.
- Python floor is 3.11, ceiling 3.14, matching upstream `runtime.py`.
- Installers still use the codex.5 bootstrap JSON file (`--json-output`) and the portable temp-dir helper. They also copy `data/` and rewrite `${CODEX_PLUGIN_ROOT}` in installed Markdown to the absolute skill path.

### Removed

- Claude Desktop / claude.ai marketplace install logic, `.claude-plugin/`, and `CLAUDE.md` as the project entrypoint.
- Claude Code hook bridge `hooks/run-python-hook.js`. Schema validation runs from the pre-commit runner instead.
- The divergent full copy of `skills/seo-firecrawl/`. The workflow is the Firecrawl extension.

### Manual testing in Codex

- Install with `install.sh` into a clean `CODEX_HOME` and confirm `~/.codex/skills/seo/scripts/codex-seo doctor` after bootstrap.
- Run `/seo audit`, `/seo agentic`, and `/seo content-brief` against a public URL.
- Install one MCP extension (Firecrawl or DataForSEO) and confirm the server appears in `~/.codex/config.toml`.
- Open a legacy `~/.config/claude-seo/google-api.json` with no Codex file and confirm `google_auth.py --check` still reads it.

## [1.9.6+codex.5] - 2026-04-28

### Fixed

- Hardened installer bootstrap JSON transport on macOS, Linux, and PowerShell by writing the bootstrap payload to a dedicated JSON file instead of scraping mixed stdout/stderr.
- Added structured JSON error output when bootstrap fails before environment verification, so platform failures produce actionable diagnostics instead of raw tracebacks.
- Added PowerShell fallback parsing through Python for large or deeply nested bootstrap payloads.
- Truncated captured subprocess logs inside bootstrap JSON to keep installer parsing stable.
- Updated public install refs to `v1.9.6-codex.5` so users receive the macOS Python 3.14 bootstrap fix from `main`.

## [1.9.6+codex.1] - 2026-04-27

### Added

- Synced Codex SEO to `AgriciDaniel/claude-seo` `main` at `a9cf338`.
- Added Codex plugin manifest at `.codex-plugin/plugin.json`.
- Expanded to 26 specialist workflows and 24 Codex TOML agent profiles.
- Added upstream backlink, cluster, local, maps, Google APIs, SXO, drift, ecommerce, FLOW, DataForSEO, image-gen, and Firecrawl workflows.
- Added upstream API/helper scripts for Google, backlinks, drift, DataForSEO, FLOW sync, reports, and verification.
- Added contract tests for plugin metadata, skill cache guidance, installer coverage, TOML agents, and FLOW sync safety.

### Changed

- Canonical skill tree is now `skills/`. `skills/seo/SKILL.md` is the main orchestrator.
- Installers default to `https://github.com/AgriciDaniel/codex-seo`.
- New credentials and runtime caches use `~/.config/codex-seo/` and `~/.cache/codex-seo/`.
- Legacy `~/.config/claude-seo/` and `~/.cache/claude-seo/` files are read only as migration fallback.
- Community footer is config-gated and disabled by default for Codex/API/client deliverables.

### Fixed

- Fixed cross-platform virtualenv Python resolution in `bootstrap_environment.py`.
- Fixed `run_headless_audit.py` `data_only` scoping for wrapper-driven audits.
- Hardened URL validation for private, loopback, reserved, multicast, unspecified, and metadata hosts.
