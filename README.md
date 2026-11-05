<p align="center">
  <img src="screenshots/cover-image.webp" alt="Codex SEO: SEO audit skill suite for Codex" width="100%">
</p>

# Codex SEO - SEO Audit Skill Suite for Codex

Codex-first SEO analysis suite with 28 sub-skills, 25 TOML agent profiles, MCP and API extensions, a managed Python runtime, and headless runners. Canonical repository: [Joseemm96/codex-seo](https://github.com/Joseemm96/codex-seo).

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Python](https://img.shields.io/badge/Python-3.11%20to%203.14-blue)](pyproject.toml)
[![Workflows](https://img.shields.io/badge/SEO_sub--skills-28-orange)](docs/COMMANDS.md)

Codex SEO is a Codex port of [`AgriciDaniel/claude-seo`](https://github.com/AgriciDaniel/claude-seo) v2.5.0. The upstream project was the source of the skill suite. This repository adapts it for Codex skills, a Codex plugin manifest, TOML agents, `~/.config/codex-seo` credentials, and repeatable local execution. AgriciDaniel/codex-seo was later renamed and is not this Codex port.

Python requirement: 3.11 to 3.14.

## Contents

- [Status](#status)
- [Install](#install)
- [Quick Start](#quick-start)
- [Commands](#commands)
- [Extensions](#extensions)
- [Architecture](#architecture)
- [Credentials And Cache](#credentials-and-cache)
- [Verification](#verification)
- [Attribution](#attribution)

## Status

- Current release: `2.5.0+codex.1`, synced to claude-seo `v2.5.0`.
- Installer default ref: `v2.5.0-codex.1`.
- 28 sub-skills: 24 core workflows, the orchestrator, the FLOW framework skill, and 2 extension mirrors (`seo-dataforseo`, `seo-image-gen`), plus Codex aliases for performance and visual inside the core count.
- Runtime credentials stay outside the repo.

## Install

### One-Line Install

```bash
curl -fsSL https://raw.githubusercontent.com/Joseemm96/codex-seo/v2.5.0-codex.1/install.sh | bash
```

Windows:

```powershell
irm https://raw.githubusercontent.com/Joseemm96/codex-seo/v2.5.0-codex.1/install.ps1 | iex
```

### Review Before Installing

```bash
git clone https://github.com/Joseemm96/codex-seo.git
cd codex-seo
bash install.sh
```

Windows:

```powershell
git clone https://github.com/Joseemm96/codex-seo.git
cd codex-seo
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

The installer copies skills into `~/.codex/skills/`, installs TOML agents into `~/.codex/agents/`, creates a virtualenv at `~/.codex/skills/seo/.venv/`, installs core requirements, attempts optional groups, and writes bootstrap status to a JSON file.

### Installer Overrides

```bash
CODEX_HOME=~/.codex \
CODEX_SEO_REPO=https://github.com/Joseemm96/codex-seo \
CODEX_SEO_REF=v2.5.0-codex.1 \
bash install.sh
```

| Variable | Purpose |
|---|---|
| `CODEX_HOME` | Alternate Codex home. Defaults to `~/.codex`. |
| `CODEX_SEO_REPO` | Git URL, fork URL, or local repository path. |
| `CODEX_SEO_REF` | Branch, tag, or commit. Defaults to `v2.5.0-codex.1`. |
| `CODEX_SEO_PYTHON` | Python interpreter for the launcher. Must be 3.11 to 3.14. |
| `CODEX_SEO_SKIP_PLAYWRIGHT_BROWSER=1` | Skip Chromium install for visual and PDF workflows. |
| `CODEX_SEO_PLAYWRIGHT_WITH_DEPS=1` | Ask Playwright to install system dependencies where supported. |

After install, skills call `"${CODEX_PLUGIN_ROOT}/scripts/codex-seo"`. Manual installs rewrite that token to `~/.codex/skills/seo/scripts/codex-seo`. Use `/seo setup` when you want the launcher to refresh the managed runtime from `requirements.txt`.

## Quick Start

Restart Codex after installation. Then ask naturally:

```text
Do a full SEO check on https://example.com following best practices.
```

```text
/seo audit https://example.com
/seo agentic audit https://example.com
/seo content-brief "local dental implants"
```

## Commands

| Prompt | Purpose |
|---|---|
| `/seo audit <url>` | Full site audit with specialist routing |
| `/seo page <url>` | Deep single-page SEO analysis |
| `/seo technical <url>` | Crawlability, indexability, security, rendering, CWV |
| `/seo content <url>` | E-E-A-T, helpfulness, readability, AI citation readiness |
| `/seo content-brief <topic>` | Detailed SEO content brief |
| `/seo schema <url>` | Structured data detection, validation, and JSON-LD |
| `/seo images <url>` | Alt text, formats, image SERP opportunities |
| `/seo sitemap <url>` | XML sitemap discovery and quality gates |
| `/seo geo <url>` | AI Overviews, ChatGPT, Perplexity, llms.txt, citability |
| `/seo agentic <url>` | Lighthouse Agentic Browsing, agent UX, WebMCP, discovery files |
| `/seo performance <url>` | Core Web Vitals via the performance agent alias |
| `/seo visual <url>` | Screenshots and above-the-fold review via the visual agent alias |
| `/seo plan <business-type>` | Strategic SEO roadmap |
| `/seo programmatic <url>` | Programmatic SEO risk and scale planning |
| `/seo competitor-pages <url>` | Comparison and alternatives page opportunities |
| `/seo hreflang <url>` | International SEO and content parity |
| `/seo local <url>` | Local SEO, GBP, NAP, citations, reviews |
| `/seo maps <command>` | Geo-grid, GBP audit, review intelligence |
| `/seo google <command>` | GSC, PageSpeed, CrUX, Indexing API, GA4 |
| `/seo backlinks <url>` | Backlink profile and source-tier detection |
| `/seo cluster <keyword>` | SERP-based topic clustering |
| `/seo sxo <url>` | Search experience and page-type fit |
| `/seo drift baseline <url>` | Capture an SEO baseline |
| `/seo ecommerce <url>` | Product SEO and product schema |
| `/seo flow <stage>` | FLOW framework prompts |
| `/seo dataforseo <command>` | Live SERP, keyword, backlink, and AI visibility data |
| `/seo firecrawl <command>` | JS-rendered crawling via the Firecrawl extension |
| `/seo image-gen <use-case>` | OG, hero, product, and infographic images |
| `/seo setup` | Create or refresh the isolated Python runtime |
| `/seo doctor` | Check runtime readiness |

Full command details live in [docs/COMMANDS.md](docs/COMMANDS.md). Upstream migration notes live in [docs/MIGRATION-v1-to-v2.md](docs/MIGRATION-v1-to-v2.md).

## Extensions

Optional installers under `extensions/` target Codex rather than Claude Desktop:

| Extension | Config |
|---|---|
| `dataforseo`, `firecrawl`, `banana`, `ahrefs` | MCP server table in `~/.codex/config.toml` |
| `profound`, `seranking`, `bing-webmaster` | `[codex_seo.<name>]` table in `~/.codex/config.toml` |
| `matomo` | `~/.config/codex-seo/matomo.json` |
| `unlighthouse` | Local `npx` runner, no API key |

`seo-firecrawl` is extension-only. Install it with `extensions/firecrawl/install.sh`. `seo-performance` and `seo-visual` are Codex skill aliases over the upstream agents so `/seo performance` and `/seo visual` still resolve.

## Architecture

```text
codex-seo/
  .codex-plugin/plugin.json
  skills/seo/SKILL.md
  skills/seo-*/
  agents/*.toml
  scripts/codex-seo          # launcher
  scripts/runtime.py
  data/google-updates.json
  extensions/
  hooks/pre-commit-schema-check.sh
  schema/
  tests/
```

Design principles:

- `skills/` is the source of truth for workflows that should auto-route.
- TOML agents are the Codex profile format.
- `"${CODEX_PLUGIN_ROOT}/scripts/codex-seo" run <script.py>` is the canonical tool call.
- New credentials go to `~/.config/codex-seo/`. Legacy `~/.config/claude-seo/` is read only when the Codex file is missing.

More detail: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Credentials And Cache

- `~/.codex/config.toml` for MCP servers and non-MCP extension keys
- `~/.config/codex-seo/` for Google, backlink, Matomo, and DataForSEO cost files
- `~/.cache/codex-seo/` for runtime caches such as drift baselines and Common Crawl
- `.seo-cache/` inside the active project for cross-skill summaries

Do not commit `.seo-cache/`, `output/`, `.env`, OAuth tokens, or provider keys.

## Verification

```bash
python -m pytest tests/
./scripts/codex-seo run portability_check.py
bash -n install.sh uninstall.sh
```

## Requirements

- Codex CLI with local skills support
- Python 3.11 to 3.14
- Git
- Optional: Playwright Chromium, Google APIs, DataForSEO, Firecrawl, and a Google AI key for image generation

## Uninstall

```bash
bash uninstall.sh
```

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

## Contributing

Use [CONTRIBUTING.md](CONTRIBUTING.md), [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md), [SECURITY.md](SECURITY.md), and [CREDITS.md](CREDITS.md). Agent context is also in [AGENTS.md](AGENTS.md).

## Related Projects

- [`claude-seo`](https://github.com/AgriciDaniel/claude-seo): original Claude Code SEO skill suite and the upstream for this port
- [`claude-blog`](https://github.com/AgriciDaniel/claude-blog): blog creation and optimization skills
- [`flow`](https://github.com/AgriciDaniel/flow): evidence-led SEO framework for AI search

## Attribution

Original project and concept by [AgriciDaniel](https://github.com/AgriciDaniel) in [`claude-seo`](https://github.com/AgriciDaniel/claude-seo) v2.5.0. This Codex port is maintained at [Joseemm96/codex-seo](https://github.com/Joseemm96/codex-seo).

Codex SEO is released under the MIT License. FLOW prompt references retain their upstream attribution and license notices.
