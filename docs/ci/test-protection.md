# Test protection and execution contract

Scope: follow-up to the 2026-10-25 audit at `25024b4e`. Audit documents are evidence inputs, not execution instructions. This packet adds PostgreSQL counterexamples and Android/macOS discovery. It deletes no tests and does not apply the separately prepared audit patch or the remaining 43 consolidation decisions.

Hosted follow-up: [PR #578 evidence](../../evidence/ci/pr578-hosted-2026-10-26.json) binds the successful full CI run `40234755323` to merge `1c39e3f9` (same Git tree as branch head `4d7c1992`). PostgreSQL 17.6: 1,673 Go results, zero failed/skipped tests, all 23 new SQL scenarios present. Android: 40 cases / 12 classes in each Kotlin mode and the actual debug APK pass. macOS: eight named cases, zero skips. All 27 jobs, including `ci-required` and Windows GUI/recovery, passed; downloaded artifact SHA256 and raw JUnit/machine outcomes were independently checked. Physical media/capacity/release gates remain separate.

Commands below start at repository root unless a working directory is named. Use the pinned SDKs in `tools/toolchains.json` and `tools/ci/toolchains/auxiliary.json`. A required platform check is `NOT_RUN`/`BLOCKED` until executed on that platform. Widget tests, compilation and test declarations do not prove physical media acceptance.

## SQL authorization suites

Set `VOICE_PLATFORM_TEST_DATABASE_URL` to a disposable loopback PostgreSQL database. The existing fixture creates one isolated schema per scenario, runs the actual embedded migrations and cleans up. Never point it at production. CI uses PostgreSQL 17.6; the local evidence in this packet uses PostgreSQL 16.

| Suite | Protected invariant | Executable command | Platform | Mandatory when | Result |
| --- | --- | --- | --- | --- | --- |
| `edit_text_message/postgres` | Only the author can edit the current revision in its live text channel; foreign/admin author, stale revision, wrong/archived/voice channel and deleted message leave persisted state unchanged | From `backend`: `go test -json -count=1 ./internal/chat/edit_text_message/postgres` | Go + real PostgreSQL; CI Ubuntu | Every selected backend database gate; edit/auth/channel changes | `.out/checks/backend.jsonl`, database profile part; mutation evidence below |
| `authorize_direct_message_attachment/postgres` | Either active DM participant can authorize; outsider and outsider administrator cannot; both peers must be active; authorization is read-only | From `backend`: `go test -json -count=1 ./internal/storage/authorize_direct_message_attachment/postgres` | Go + real PostgreSQL; CI Ubuntu | Every selected backend database gate; DM/storage/ACL changes | Same backend event stream and database part |
| `publish_screen_descriptor/postgres` | Only the matching active account/session/lease in an open, live voice channel can publish and persist a receipt; denial causes zero publisher calls and no receipt change | From `backend`: `go test -json -count=1 ./internal/media/publish_screen_descriptor/postgres` | Go + real PostgreSQL; CI Ubuntu | Every selected backend database gate; media/session/revocation changes | Same backend event stream and database part |

`task test:sql-authorization` (equivalently `python -m tools.verify.sql_authorization.run`) copies the backend into a temporary directory, executes the uncached baseline, applies each audited mutation separately, requires its negative witness to fail, restores exact bytes and repeats the baseline. It requires the DSN above. Results: `.out/checks/sql-authorization/{result.json,baseline.jsonl,mutation-1.jsonl,mutation-2.jsonl,mutation-3.jsonl,restored.jsonl}`. Checked-in local evidence is linked from `evidence/ci/test-sql-native-gates-2026-10-25.json`.

| Mutation | Required failing witness |
| --- | --- |
| Author predicate widened with `OR TRUE` | `TestPostgresEditAuthorization/foreign_author` |
| DM membership widened with `OR TRUE` | `TestPostgresAttachmentPairAuthorization/outsider_administrator` (ordinary outsider also fails) |
| Session revocation widened with `OR TRUE` | `TestPostgresDescriptorAdmission/revoked_session` |

The original binding, row-mapping and error tests remain. The backend workflow retains the per-test event stream as mandatory `backend-events-<sha>-<run>-<attempt>` artifact (30 days). The real publisher is intentionally replaced by a recording publisher here; these are SQL authorization tests, not a LiveKit/media acceptance claim. Missing DSN is a visible fixture skip; the normal backend event verifier and mutation runner reject it.

## Android suites: every class, both Kotlin modes

`A` means `task test:android-unit`, which executes **both** legacy and built-in Kotlin modes, in fresh output directories with Java/Android/Flutter SDKs installed. It resolves the locked app dependencies and performs the existing builds, including generation of the ignored Gradle wrapper. Individual test invocations after the corresponding build: `python -m tools.verify.android_unit.run legacy` and `python -m tools.verify.android_unit.run builtin` from root. An app dependency restore alone does not initialize a fresh checkout's Gradle wrapper.

The existing mandatory `android-kotlin` profile runs both through `tools/verify/android_kotlin/verify_android_kotlin_modes.sh`, after each corresponding real build. Gradle executes `:boohtacord_voice_foreground:testDebugUnitTest`, `:livekit_client:testDebugUnitTest`, and `:flutter_webrtc:testDebugUnitTest` with `--rerun-tasks`. LiveKit now explicitly uses the JUnit 4 Kotlin adapter and runner to match these tests.

For **every row**: platform = Android local JVM unit tests (hosted Ubuntu, Java 17); trigger = every shared-selector Flutter/native gate, including native/vendor/contract/toolchain changes and Android release quality. Result = `.out/checks/android-unit/<mode>/<plugin>/TEST-<class>.xml` and `<mode>/result.json`, uploaded as `android-unit-<namespace>-<sha>-<run>-<attempt>`, retained 30 days. The Flutter aggregate also requires successful `android-kotlin` execution and upload. These are JVM tests, not emulator/device evidence.

| Plugin / class | Protected invariant | Command | Required cases per mode |
| --- | --- | --- | --- |
| `boohtacord_voice_foreground` / `ru.boohtacord.voice.start.AdmissionPolicyTest` | Foreground/active service and microphone permission admission | A | 5 |
| `livekit_client` / `io.livekit.plugin.AudioResamplerTest` | Resampling frame/sample counts, channel separation and boundaries | A | 11 |
| `flutter_webrtc` / `com.cloudwebrtc.webrtc.record.FrameCaptureGateTest` | Capture frame gate admits/rejects at the intended boundary | A | 2 |
| `flutter_webrtc` / `com.cloudwebrtc.webrtc.record.FrameCapturerBufferTest` | Direct buffer contents survive capture copying | A | 1 |
| `flutter_webrtc` / `com.cloudwebrtc.webrtc.RemoteTrackRegistryTest` | Replacement/detachment preserves the current remote track | A | 1 |
| `flutter_webrtc` / `com.cloudwebrtc.webrtc.ScreenCaptureConstraintsTest` | Screen constraints preserve requested dimensions/rate | A | 3 |
| `flutter_webrtc` / `com.cloudwebrtc.webrtc.ScreenCaptureDimensionsTest` | Capture dimensions respect source orientation and limits | A | 6 |
| `flutter_webrtc` / `com.cloudwebrtc.webrtc.ScreenCaptureFrameRateGateTest` | Frame cadence follows the configured rate | A | 3 |
| `flutter_webrtc` / `com.cloudwebrtc.webrtc.SurfaceProducerAvailabilityTest` | Unavailable/released surface cannot render until available | A | 1 |
| `flutter_webrtc` / `com.cloudwebrtc.webrtc.SurfaceReleaseBarrierTest` | Surface release observes the outstanding render barrier | A | 3 |
| `flutter_webrtc` / `com.cloudwebrtc.webrtc.utils.ConstraintsMapTest` | Numeric constraint values retain their type/value | A | 1 |
| `flutter_webrtc` / `com.cloudwebrtc.webrtc.VideoFrameDimensionsTest` | Video frame dimensions preserve rotation/size semantics | A | 3 |

The reviewed inventory pins **12 classes / 40 cases per mode**. Source loss/addition requires review; actual JUnit children must match each class count. Missing XML/class, duplicate case, skipped/failed/error case, contradictory suite failure totals or stale output directory cannot pass. A global count from a different class is insufficient. Fresh CI workspaces own outputs; preserve old local evidence before removing only the owned per-mode output directory for a rerun.

## Apple suites

| Suite | Protected invariant | Command | Platform | Mandatory when | Result |
| --- | --- | --- | --- | --- | --- |
| LiveKit `screen_capture_engine_test.dart` (8 named cases, including 2 Apple-only) | Capture engine/source/FPS constraints, diagnostics flags, copy/from behavior | `task test:macos-unit` / `python -m tools.verify.macos_unit.run` | Actual macOS; hosted `macos-26` in CI | Every selected Flutter gate, macOS full-build dispatch and macOS release/dry-run before build | `.out/checks/macos-unit/{result.json,screen-capture-engine.jsonl}`; `macos-unit-*` upload, 30 days |
| Copied Mac QA unit suites (all 9 `qa_copy_plan()` tests) | Lifecycle restart/rejoin observations, receiver descriptor ordering/privacy, capture/source/storage/HTTP observer and deadline behavior | `python -m tools.qa.macos_sender.run`; candidate: `python -m tools.qa.macos_sender.candidate --template <owned-template>` | Physical Mac QA environment and its SDK lease | Each corresponding QA build before compiling the owned app | Owned private build log; public `runtime.json` / `candidate-build-proof.json` under the configured QA output root |

The new `macos` child belongs to the existing `ci-flutter.yaml` selector, with no second path filter. `flutter` now requires `dart`, `android`, `android-kotlin`, **and `macos`**. Missing/skipped/failed/stale Apple parts fail aggregation. Existing Android signing depends on that complete gate. macOS release independently runs the vendor suite before building. No signing, deployment or publication was performed by this packet.

The Apple test runner refuses non-Apple hosts, requires every named case and a successful completed machine-event stream, and rejects skips/failures. Both Mac QA build lists now include lifecycle and receiver tests; candidate also includes all other copied QA tests. Actual QA test execution and physical capture remain separate evidence. Historical three-profile timing samples do not measure this expanded four-profile gate; shadow measurement now accounts for the Apple jobs and artifacts explicitly.

## Preserved surrounding gates

These aggregate rows link to their authoritative per-operation inventories; they do not certify all historical inventory entries or claim a full run here.

| Suite | Protection | Canonical command | Platform / mandatory trigger | Result |
| --- | --- | --- | --- | --- |
| Tools/contracts | Contract/schema/traceability, workflow trust, routing, release/security negative boundaries | `task check:contracts`; Python suite: `python -m tools.verify.python_tests.run` | Ubuntu CI contracts on every change; pinned Python/Node/Go/pwsh/Docker | Actions contracts log; release receipt `.out/checks/contracts.json` |
| Backend static | Type/build/vet correctness | `python -m tools.ci.backend_gates.run --profile static` | Ubuntu; selected backend gate | `.out/ci/backend-parts/static.json` |
| Backend database, all ordinary Go tests | Persistence/migrations/server ACL/session/DM invariants; no skipped Go tests | `python -m tools.ci.backend_gates.run --profile database` | Ubuntu + PostgreSQL 17.6; selected backend gate | `.out/checks/backend.jsonl`, `.out/ci/backend-parts/database.json` |
| Backend load smoke | Original bounded normal/reconnect/upload/NAT/fault API scenarios | `python -m tools.ci.backend_gates.run --profile load` | Disposable Ubuntu/Docker; selected backend gate | `.out/ci/backend-parts/load.json`, `.out/backend-load/**/report.json` |
| Installation telemetry acceptance | Two-installation isolation, concurrent first boot, revoke/reset | `python -m tools.qa.installation_telemetry.run` | Backend database gate, existing owned runtime | Installation-telemetry result/logs from that controller; database part records completion |
| Web six profiles | DSP/unit/build; shell/content/conversation/voice UI; real SFU/network scenarios | `python -m tools.ci.native.web --profile <fast\|browser-shell\|browser-content\|browser-conversations\|browser-voice\|sfu-network>` | Ubuntu; selected Web gate; browser/SFU prerequisites per profile | `.out/ci/web-parts/<profile>.json`; [exact operation map](../../tools/ci/web_suites/plan-v1.json), [gate evidence](web-gates.md) |
| Flutter app and vendor Dart | App and both vendor behaviors, analysis, public headers, widget captures | `python -m tools.ci.native.flutter` | Ubuntu Dart gate and Windows native unit gate | Dart profile part + mandatory widget captures; [Flutter gate](flutter-gates.md) |
| Android debug APK | Actual package build, application/signing/ABI/size identity | `python -m tools.ci.flutter_gates.run android` (Actions context) | Ubuntu/Android SDK; selected Flutter gate | `.out/native/android-debug/`, `.out/ci/flutter-parts/android.json` |
| Windows native/unit/build/GUI | Native recovery, app/vendor unit tests; one measured executable and real recovery/GUI/SFU acceptance | `python -m tools.ci.native.flutter`, `python -m tools.build.windows.run --ci-acceptance`, `python -m tools.ci.windows_gates.acceptance` | Windows; selected Windows gate, original dependencies unchanged | `.out/ci/windows-{transfer,acceptance}.json`, `.out/releases/windows/`; [platform gate](windows-gates.md) |
| Actual lifecycle/next/SFU | Real API/PostgreSQL/TLS/browser/SFU journeys and cleanup | `python -m tools.ci.actual_acceptance.run --profile <profile> --baseline <sha>` | Disposable hosted Ubuntu; shared risk selector | `.out/actual-acceptance/public/<profile>/`; [requirements and artifact contract](actual-acceptance.md) |
| Media QoE / roster PromQL | Missing telemetry, alert thresholds and dashboard/rule semantics | Exact pinned `promtool check rules` / `test rules` commands in `.github/workflows/ci-contracts.yaml` | Ubuntu/Docker contracts gate | Actions step logs and generated `.out/media-qoe/`, `.out/voice-roster/` |
| Physical/security/capacity/release | Secure sessions/ACL and real revocation; OS audio/capture; supported capacity and installed-update journey | Existing scenario controllers and release/physical requirements in `tools/ci/actual_acceptance/plan-v1.json` | Matching actual devices/OS/hardware; required by risk/release selection | Source-bound `evidence/` records; unavailable/failed gates remain open |

## Explicit outstanding discovery work

The supplied earlier patch is absent at this base: the 11 Python top-level functions and other prior-patch changes are not silently claimed fixed here. That patch needs separate application/review before closing the audit. No deletion in it is approved by this follow-up.

The audit also identifies Web `stage.vitest.config.ts`, `voice_timeout/playwright.config.ts` and notification PromQL query-profile routing. Their automatic discovery is outside this SQL/Android/macOS packet and remains **OPEN**, not PASS. The eight Go `tracing_runtime` scenarios retain their documented manual runtime/outage route in [tracing QA](../../tools/qa/tracing_flow/README.md); ordinary `go test ./...` does not cover them. Their runtime evidence is mandatory when claiming tracing-runtime/outage acceptance. None of these gaps justifies deleting their source.

## Deletion decision contract

Before any of the remaining 43 consolidation decisions, retain one record with: removed test ID and its invariant; surviving **executed** production test ID/command/platform; exact counterexample/mutation and failing witness; baseline/restored results; per-module/class discovery and skip delta; applicable security/platform/media gate results and evidence paths. Failures due to compilation/setup do not count as killing a behavior mutation. A pending platform run cannot authorize removal of its unique protection. This packet removes neither declarations nor assertions.
