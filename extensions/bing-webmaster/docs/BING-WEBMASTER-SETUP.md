# Bing Webmaster Tools + IndexNow extension setup

## What this gives you

1. **Bing Webmaster Tools API**: inbound links, crawl stats, search
   keywords, and competitor link comparison via
   `"${CODEX_PLUGIN_ROOT}/scripts/codex-seo" run bing_webmaster.py` (already shipped with codex-seo).
2. **IndexNow URL submission** for Amazon, Bing, Naver, Seznam.cz,
   Yandex, and Yep via `"${CODEX_PLUGIN_ROOT}/scripts/codex-seo" run indexnow_submit.py`.
3. A unified `seo-bing` skill that routes the right command at the
   right script.

## Install

```bash
./extensions/bing-webmaster/install.sh
.\extensions\bing-webmaster\install.ps1
```

You'll be prompted for:

- Bing Webmaster Tools API key (https://www.bing.com/webmasters/api)
- IndexNow host key (any random 32+ char string)
- IndexNow keyLocation URL (must serve the key file at that URL)

Both groups can be left blank if you only want one. The installer
writes the Bing key into `~/.config/codex-seo/backlinks-api.json` and the
IndexNow key into `~/.config/codex-seo/indexnow.json`. `backlinks_auth.py`
and `indexnow_submit.py` read those files. Environment variables still
override them.

## IndexNow setup checklist

1. Generate a key: `openssl rand -hex 32`
2. Save the key to a file at the **root** of your site, named `<key>.txt`,
   served at `https://example.com/<key>.txt`. The file body is the key.
3. Run:
   ```
   /seo bing verify-indexnow
   ```
   The verifier fetches your keyLocation URL and confirms the body
   matches the key, the #1 onboarding mistake.

## Microsoft Copilot citation

Microsoft Copilot pulls citations from the Bing index. Pages that
aren't in Bing aren't citable. IndexNow notifies participating
engines about changed URLs and can speed discovery, but it does not
guarantee indexing speed.

## Uninstall

```bash
./extensions/bing-webmaster/uninstall.sh
```

PowerShell:

```powershell
.\extensions\bing-webmaster\uninstall.ps1
```

The uninstaller deletes the skill, the Bing key inside the shared backlink
credential file, `~/.config/codex-seo/indexnow.json`, and a legacy
`[codex_seo.bing]` table if one is still present. Other backlink keys stay.
