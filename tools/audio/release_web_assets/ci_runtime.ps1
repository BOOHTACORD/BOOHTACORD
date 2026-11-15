$ErrorActionPreference = 'Stop'
foreach ($name in @('BOOHTA_RESEARCH_ASSET_DIR', 'BOOHTA_DEEPFILTER_RESEARCH_BUNDLE', 'VITE_DEEPFILTER_ENABLED')) {
    Remove-Item -LiteralPath ('Env:' + $name) -ErrorAction SilentlyContinue
}
Push-Location clients/web
try {
    npx playwright test -c tests/audio/playwright.production.config.ts
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally { Pop-Location }
python -m tools.audio.research_dfn_web.livekit_windows --binary "$env:RUNNER_TEMP/livekit/livekit-server.exe" --web clients/web --config tests/audio/playwright.production_sfu.config.ts --test production_livekit.local.ts
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
