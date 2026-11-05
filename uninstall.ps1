# Codex SEO Uninstaller for Windows

$ErrorActionPreference = "Stop"

$codexRoot = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }
$skillsRoot = Join-Path $codexRoot "skills"
$agentDir = Join-Path $codexRoot "agents"

$skillNames = @(
    "seo",
    "seo-agentic",
    "seo-audit",
    "seo-backlinks",
    "seo-cluster",
    "seo-competitor-pages",
    "seo-content",
    "seo-content-brief",
    "seo-dataforseo",
    "seo-drift",
    "seo-ecommerce",
    "seo-flow",
    "seo-firecrawl",
    "seo-geo",
    "seo-google",
    "seo-hreflang",
    "seo-image-gen",
    "seo-images",
    "seo-local",
    "seo-maps",
    "seo-page",
    "seo-performance",
    "seo-plan",
    "seo-programmatic",
    "seo-schema",
    "seo-sitemap",
    "seo-sxo",
    "seo-technical",
    "seo-visual"
)

$agentNames = @(
    "seo-agentic",
    "seo-backlinks",
    "seo-cluster",
    "seo-competitor-pages",
    "seo-content",
    "seo-dataforseo",
    "seo-drift",
    "seo-ecommerce",
    "seo-flow",
    "seo-firecrawl",
    "seo-geo",
    "seo-google",
    "seo-hreflang",
    "seo-image-gen",
    "seo-images",
    "seo-local",
    "seo-maps",
    "seo-performance",
    "seo-plan",
    "seo-programmatic",
    "seo-schema",
    "seo-sitemap",
    "seo-sxo",
    "seo-technical",
    "seo-visual"
)

Write-Host "[INFO] Uninstalling Codex SEO..." -ForegroundColor Yellow

$removedSkills = 0
$removedAgents = 0
foreach ($subSkill in @(Get-ChildItem -Path $skillsRoot -Directory -Filter "seo*" -ErrorAction SilentlyContinue)) {
    Remove-Item -Path $subSkill.FullName -Recurse -Force
    $removedSkills++
}
foreach ($agentFile in @(Get-ChildItem -Path $agentDir -Filter "seo-*" -ErrorAction SilentlyContinue)) {
    Remove-Item -Path $agentFile.FullName -Force
    $removedAgents++
}

foreach ($skill in $skillNames) {
    $path = Join-Path $skillsRoot $skill
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force
    }
}

foreach ($agent in $agentNames) {
    foreach ($extension in @(".toml", ".md")) {
        $path = Join-Path $agentDir "$agent$extension"
        if (Test-Path $path) {
            Remove-Item -Path $path -Force
        }
    }
}

Write-Host "[OK] Codex SEO uninstalled." -ForegroundColor Green
