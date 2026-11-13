$ErrorActionPreference = 'Stop'
$archive = "$env:RUNNER_TEMP/livekit.zip"
Invoke-WebRequest 'https://github.com/livekit/livekit/releases/download/v1.13.7/livekit_1.13.7_windows_amd64.zip' -OutFile $archive
$hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
if ($hash -ne 'e539e7d2f75807b9c9202cd2a0bf2cb3d52fc4c52978a6953e0f47bc339fe77f') { throw 'LiveKit archive identity mismatch' }
Expand-Archive -LiteralPath $archive -DestinationPath "$env:RUNNER_TEMP/livekit"
$env:BOOHTA_RESEARCH_ASSET_DIR = "$env:RUNNER_TEMP/dfn-stage"
Push-Location clients/web
try {
  node node_modules/@playwright/test/cli.js test -c tests/audio/playwright.deepfilter.config.ts deepfilter_loader.research.spec.ts deepfilter_track.research.spec.ts deepfilter.research.spec.ts
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  $env:CHROMIUM_EXECUTABLE_PATH = Join-Path ${env:ProgramFiles(x86)} 'Microsoft/Edge/Application/msedge.exe'
  if (-not (Test-Path -LiteralPath $env:CHROMIUM_EXECUTABLE_PATH)) { throw 'Microsoft Edge not found' }
  node node_modules/@playwright/test/cli.js test -c tests/audio/playwright.deepfilter.config.ts deepfilter_loader.research.spec.ts deepfilter_track.research.spec.ts deepfilter.research.spec.ts
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally { Pop-Location }
Remove-Item Env:CHROMIUM_EXECUTABLE_PATH
$server = "$env:RUNNER_TEMP/livekit/livekit-server.exe"
python -m tools.audio.research_dfn_web.livekit_windows --binary $server --web clients/web --config tests/audio/playwright.deepfilter.config.ts --test deepfilter_livekit.research.spec.ts
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$env:VITE_DEEPFILTER_ENABLED = 'true'
$env:BOOHTA_DEEPFILTER_RESEARCH_BUNDLE = "$env:RUNNER_TEMP/dfn-web/bundle"
python -m tools.audio.research_dfn_web.livekit_windows --binary $server --web clients/web --config tests/audio/playwright.deepfilter.config.ts --test deepfilter_switch_livekit.research.spec.ts
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$env:CHROMIUM_EXECUTABLE_PATH = Join-Path ${env:ProgramFiles(x86)} 'Microsoft/Edge/Application/msedge.exe'
python -m tools.audio.research_dfn_web.livekit_windows --binary $server --web clients/web --config tests/audio/playwright.deepfilter.config.ts --test deepfilter_livekit.research.spec.ts
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
