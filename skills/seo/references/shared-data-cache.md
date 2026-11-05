# Shared data cache

Codex SEO skills share optional evidence in `.seo-cache/` at the project root.
A missing, stale, or unreadable cache is not an error. Continue with a fresh collection.

## Rules

- Location: `.seo-cache/`
- Do not commit cache files
- Corrupt JSON counts as a missing cache
- Permission errors are skipped
- `refresh` or `re-run` ignores the cache
- New credential files go to `~/.config/codex-seo/`
- Legacy `~/.config/claude-seo/` and `~/.cache/claude-seo/` are read only when the Codex path is absent

## Layout

```text
.seo-cache/
  site-meta.json
  audit-scores.json
  pages/
```

Each JSON file should include the URL, an analysis timestamp, and the producing skill name.
