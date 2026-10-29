# PR #599 final implementation and delivery evidence

[PR #599](https://github.com/Egkurilov/BOOHTACORD/pull/599) is merged into master as
`b4d31188b56d61f8a6b6c4ed26ba29d5f528a3c8` (tree `f2141cabe3c631eb8692e7fd6fd06b76ac7f21ca`).
The tested synthetic merge has this exact tree. This folder is an additive receipt;
the earlier physical failures and the frozen QA matrix remain unchanged.

## Invariant -> command -> platform -> mandatory trigger -> result

Commands run from repository root unless a working directory is stated.
CI commands require the workflow's pinned environment and evidence variables.

| Protection | Command | Platform | Mandatory when | Result/evidence |
| --- | --- | --- | --- | --- |
| Own attachment survives minimal 201 without realtime; exact owner/DM/revision/session fences and no duplicate POST | T115 below | Windows Flutter 3.47.7 / Android widget target | Accepting #598 send/readback changes | 115 PASS, 0 skips; [original RED/GREEN](https://github.com/Egkurilov/BOOHTACORD/blob/b4d31188b56d61f8a6b6c4ed26ba29d5f528a3c8/evidence/qa/issue598-attachment-send-hydration-2026-10-29.md) |
| Full shared app behavior and matching profile build label | `flutter test --no-pub --reporter json` in clients/flutter | Windows headless Flutter | Accepting the final merged Flutter tree | 1683 PASS, 0 failures, 3 unchanged opt-in skips; local-final-app-tests.json |
| Dart/vendor behavior and finite synthetic capture publication | `python3 -m tools.ci.flutter_gates.run dart` | Hosted Ubuntu | Applicable Flutter PR gate | PASS; all 165 logical captures byte-verified; hosted-profile-verification.json |
| Android manifest, contracts, ABI and actual APK identity | `python3 -m tools.ci.flutter_gates.run android` | Hosted Ubuntu / Java 17.0.20+101 | Applicable Android build gate | PASS; debug-apk-inspection.json; debug APK not installed |
| Android native unit behavior in both Kotlin modes | `python3 -m tools.ci.flutter_gates.run android-kotlin` | Hosted Ubuntu / pinned Android toolchain | Applicable Android native gate | 51 PASS per mode; hosted-profile-verification.json |
| Apple-only native vendor behavior without skips | `python3 -m tools.ci.flutter_gates.run macos` | macos-26-intel | Applicable macOS native gate | 8 PASS, 0 skips; hosted-profile-verification.json |
| Backend static, actual database and isolated smoke behavior | `python3 -m tools.ci.backend_gates.run --profile static`, then `--profile database`, then `--profile load` | Hosted Ubuntu / PostgreSQL 17.6 | Applicable backend gate | 1677 Go test PASS events, 0 test skips/failures; source-and-ci.json and hosted-artifacts.json |
| Windows native unit/build, verified transfer, actual GUI/SFU and recovery | Entrypoints in .github/workflows/flutter-windows.yaml, including `python -m tools.ci.windows_gates.acceptance` and `.aggregate` | Hosted Windows | Applicable Windows native gate | All corresponding final CI jobs SUCCESS; source-and-ci.json |
| Public catalog readable by nonroot while private environment remains private | `python -B -m unittest tools.release.install.public_catalog.test_prepare tools.release.client_updates.test_permissions -v` | Disposable Linux / umask 077 / uid 65532 | Installer/catalog publication changes | 9 PASS, 0 skips; [actual RED/GREEN and controls](https://github.com/Egkurilov/BOOHTACORD/blob/b4d31188b56d61f8a6b6c4ed26ba29d5f528a3c8/evidence/qa/issue249-public-catalog-readability-2026-10-29.json) |
| Runtime parses the actual source catalog and selects both native policies | `go test -json -count=1 ./internal/client_updates/catalog` in backend | Windows Go 1.26.4 | Catalog availability changes | 14 top-level + 2 subtest PASS, 0 skips/failures; same source evidence |
| Complete current source/run/attempt CI gate | `python3 -m tools.ci.required_gate.run` in CI workflow | Hosted Ubuntu | Before merge | [27/27 SUCCESS](https://github.com/Egkurilov/BOOHTACORD/actions/runs/40836380333), attempt 1; source-and-ci.json |
| Exact approved producer bundle installed and source read back | Existing Build server -> Deploy production workflows | Approved production deployment | After merge affecting server runtime | PASS; actual install 08:12:50-08:14:29 UTC; delivery-proof.json |
| Windows catalog equals source policy; Android selector remains available | Public read-only GET selectors below | Production HTTPS, default TLS, no cookies/auth/redirects | After actual approved installation | Both HTTP 200, no-store/nosniff, revision 29 at 08:15:27 and 08:30:35 UTC; delivery-proof.json and public-stable-readback.json |
| Signed physical JPEG/GIF picker/Send, peer integrity, ACL and delete/revocation | Physical scenario plus `./tools/qa/local_features/check.sh --feature chat --feature shell --base cfda847b6d608f38e4b785ffca0da1fdb6a5dd30 --real-stack` with applicable native target | Actual connected Android | Before physical #598 closure | NOT_RUN/BLOCKED: no ADB devices, local canonical harness bootstrap unavailable |
| Historical Windows 1.0.32 -> 1.0.38 real update flow | Original #249 checklist | Isolated agreed old Windows client fixture | Before whole #249 closure | NOT_RUN; installed newer client was not downgraded |

T115, working directory `clients/flutter`:

```sh
flutter test --no-pub --reporter expanded \
  test/direct_send_hydration/ \
  test/delivery_recovery_test.dart test/delivery_lookup_api_test.dart \
  test/delivery_status_widget_test.dart test/app_state_test.dart \
  test/conversation_scope/ test/attachment_revocation_test.dart \
  test/message_attachment_list_test.dart test/message_attachment_composer_test.dart
```

Public selectors (two bounded GETs, no mutations):

```sh
curl --fail --max-time 20 --proto '=https' -i 'https://v.bootybay.ru/api/v1/client-updates?platform=windows&distribution=direct&channel=stable&arch=x64'
curl --fail --max-time 20 --proto '=https' -i 'https://v.bootybay.ru/api/v1/client-updates?platform=android&distribution=direct&channel=stable&arch=arm64'
```

## Evidence scope and integrity

The 14 CI artifact ZIPs were independently downloaded and their actual bytes,
sizes, digests and source/run/attempt bindings checked. hosted-artifacts.json
preserves the measured hashes and original expiration times. JSON metadata is
retained here; generated media, APKs, raw logs and private data are not committed.
The two 390x844 hosted synthetic frames were viewed at source resolution:
painted own image, filename/size/download controls, empty composer, no pending
chip or clipping. GIF animation and physical rendering are NOT_RUN.

The tiny deployment receipt ZIP was independently byte-verified and its producer,
source, install stages, readback time, schema and persistent-volume hashes checked.
The observer did not independently download the 89 MB server bundle. Receipt
validation proves the recorded installation; later public GETs prove endpoint state.
Source catalog SHA256 `93fad894cbee438f42dad99ce9558134011422c07ab6f8f1ea9045e406a99fbf`
hashes Git/LF bytes; the Windows observer's `09837a...` hashes canonical JSON.
These are different documented hash schemes, not equal-byte claims.

[Master native quality](https://github.com/Egkurilov/BOOHTACORD/actions/runs/40839323048),
[Build server](https://github.com/Egkurilov/BOOHTACORD/actions/runs/40839323065) and
[Deploy production](https://github.com/Egkurilov/BOOHTACORD/actions/runs/40840487249)
also completed SUCCESS on the merged source. Windows source target remains
revision 29 / windows-direct-stable-r52 / 1.0.38 build 71; other entries are retained.
This fixes the observed catalog 503; old-client update and new signed Android
physical acceptance remain open. The 43 consolidation decisions were untouched.

SHA256.json covers the eight retained JSON evidence files; this README is prose.
