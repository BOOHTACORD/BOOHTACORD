$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$policyView = Join-Path $root '.out/action-policy'
python -m tools.verify.action_pins.run --policy-view $policyView
if ($LASTEXITCODE -ne 0) { throw 'Unreviewed or mutable Actions reference.' }
$names = @(
    'android-release.yaml', 'audit-attachment-volume.yaml', 'deploy-production.yaml',
    'flutter-macos.yaml', 'flutter-windows.yaml', 'macos-release.yaml',
    'qa08-active-upload.yaml', 'qa11-preflight.yaml', 'rehearse-compatible-rollback.yaml'
)
foreach ($name in $names) {
    $path = Join-Path $root ".github/workflows/$name"
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing GitHub workflow: $name" }
    $source = Get-Content -LiteralPath $path -Raw
    if ($source -match 'gitverse\.|GITVERSE_OUTPUT|api\.gitverse\.ru|\.gitverse/workflows') {
        throw "GitVerse-specific runtime remains in $name"
    }
}
if (Test-Path -LiteralPath (Join-Path $root '.gitverse/workflows')) {
    throw 'Legacy GitVerse workflow directory remains active.'
}
python -m tools.verify.workflows.delivery
if ($LASTEXITCODE -ne 0) { throw 'Signed delivery workflow validation failed.' }

$tracked = @(git -C $root ls-files -- artifacts clients/flutter/build clients/web/dist clients/flutter/packages/flutter_webrtc/third_party)
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect tracked build outputs.' }
$generated = @($tracked | Where-Object {
    $_ -match '^artifacts/.*\.(apk|aab|ipa|zip|dmg|msix|exe|dll|pdb|lib)$' -or
    $_ -match '^(clients/flutter/build|clients/web/dist)/' -or
    $_ -match '^clients/flutter/packages/flutter_webrtc/third_party/(downloads|libwebrtc)/'
})
if ($generated.Count -gt 0) {
    throw "Generated build outputs are tracked by Git: $($generated -join ', ')"
}

$windows = Get-Content -LiteralPath (Join-Path $policyView 'flutter-windows.yaml') -Raw
if ($windows -notmatch 'uses:\s*actions/upload-artifact@v4' -or
    $windows -notmatch 'path:\s*clients/flutter/build/windows/x64/runner/Release/' -or
    $windows -notmatch 'if-no-files-found:\s*error' -or
    $windows -notmatch 'retention-days:\s*30') {
    throw 'Windows CI must retain the full release directory as a fail-closed workflow artifact.'
}
foreach ($required in @('workflow_call:', 'runs-on: windows-2022',
    'uses: ./.github/actions/flutter-setup', 'flutter-version: 3.47.7',
    'python -m tools.build.windows.run --ci-acceptance', 'python -m tools.ci.native.flutter',
    'python -m tools.ci.windows_gates.transfer seal', 'python -m tools.ci.windows_gates.transfer verify',
    'python -m tools.ci.windows_gates.acceptance', 'python -m tools.ci.windows_gates.aggregate')) {
    if (-not $windows.Contains($required)) {
        throw "Windows CI must run on a hosted runner before merge: $required"
    }
}
$macos = Get-Content -LiteralPath (Join-Path $policyView 'flutter-macos.yaml') -Raw
if ($macos -notmatch 'bash tools/build/macos/package.sh' -or
    $macos -notmatch 'uses:\s*actions/upload-artifact@v4' -or
    $macos -notmatch 'if-no-files-found:\s*error' -or
    $macos -notmatch 'retention-days:\s*30') {
    throw 'macOS CI must package and retain its ZIP and checksum as a workflow artifact.'
}
$ci = Get-Content -LiteralPath (Join-Path $policyView 'ci.yaml') -Raw
$flutterCiPath = Join-Path $policyView 'ci-flutter.yaml'
python -m tools.verify.workflows.selection
if ($LASTEXITCODE -ne 0) { throw 'CI component dependency validation failed.' }
$flutterCi = Get-Content -LiteralPath $flutterCiPath -Raw
foreach ($required in @(
    'workflow_call:', 'runs-on: ubuntu-24.04', 'flutter-version: 3.47.7',
    'python3 -m tools.ci.flutter_gates.run dart',
    'python3 -m tools.ci.flutter_gates.run android',
    'python3 -m tools.ci.flutter_gates.aggregate'
)) {
    if (-not $flutterCi.Contains($required)) {
        throw "Flutter CI gate is missing: $required"
    }
}
if ($flutterCi -notmatch 'uses:\s*actions/upload-artifact@v4' -or
    $flutterCi -notmatch 'path:\s*\.out/native/android-debug/' -or
    $flutterCi -notmatch 'if-no-files-found:\s*error' -or
    $flutterCi -notmatch 'retention-days:\s*30') {
    throw 'Flutter CI must retain the built debug APK as a fail-closed workflow artifact.'
}
python -m tools.verify.workflows.native
if ($LASTEXITCODE -ne 0) { throw 'Native signing and artifact retention validation failed.' }
Write-Output 'GitHub workflow routing: OK'
