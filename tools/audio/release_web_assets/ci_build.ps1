$ErrorActionPreference = 'Stop'
$env:PYTHONUTF8 = '1'
python -m unittest tools.audio.release_source.test_verify tools.audio.release_notices.test_collect tools.audio.release_deepfilter.test_compiler tools.audio.release_deepfilter.test_signing
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
git clone --filter=blob:none --no-checkout https://github.com/emscripten-core/emsdk.git .out/emsdk
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
git -C .out/emsdk checkout --detach e4fe26ef59168ff44f4c23c466e497bf60b3411e
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if ((git -C .out/emsdk rev-parse HEAD).Trim() -ne 'e4fe26ef59168ff44f4c23c466e497bf60b3411e') { throw 'Emsdk source mismatch' }
& ./.out/emsdk/emsdk.bat install 4.0.20
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& ./.out/emsdk/emsdk.bat activate 4.0.20
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$env:EM_CONFIG = (Resolve-Path .out/emsdk/.emscripten).Path
python -m tools.audio.release_rnnoise.build --output "$env:RUNNER_TEMP/rnnoise-production" --emcc .out/emsdk/upstream/emscripten/emcc.bat
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
python -m tools.audio.release_web_assets.verify_rebuild --rnnoise "$env:RUNNER_TEMP/rnnoise-production" --deepfilter "$env:RUNNER_TEMP/dfn-web/bundle"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
node --test tools/audio/release_web_assets/bundle.test.mjs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
python -m unittest tools.audio.release_web_assets.test_verify_rebuild
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
