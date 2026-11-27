# Issue 785: playback promotion and isolated recovery

Status: **PASS_SCOPED** for the cases below. `gate_closed: false`. Baseline: `4a532e4c67d5322f9cec8fc350390227d7653b21` (master at intake). Runs used
a dirty candidate, not clean master. The Windows Flutter checkout and canonical Linux QA copy matched after UTF-8/LF normalization for all 17 files.

## Reproduced defects and preservation

- Two playback-start regressions failed before implementation; the native-stop replacement case preserved an existing behavior. Concurrent starts now
  share one admission; obsolete completions/failures cannot change or stop a successor.
- Three UI-sync regressions failed before request fencing: stale start/admission replies and late deafen cleanup could overwrite a newer availability
  notice.
- API33 native resume first timed out: Flutter stayed inactive, did not draw, and Android reported no focused window/ANR while audio counters
  progressed. Diagnostic pumping exposed the surface; that altered run is not counted PASS. Live test frames during the lifecycle wait resolved the
  fresh native run. Two frame-policy tests failed with a passthrough wrapper, then passed with policy restoration on both normal completion and
  timeout. OS resume remains required; no lifecycle, media, timing or cleanup assertions were removed.
- Earlier missing-device-flag and stale-control setup attempts are retained as failed setup attempts. Bridge argv forwarding and explicit owned-AVD
  cache cleanup corrected setup; these attempts are not product PASS evidence.

## Checks

- Existing playback preservation baseline: 7 PASS. Final production-focused suite: 37 PASS; resume-frame/wait plus playback subset: 24 PASS
  (overlapping).
- Final Windows Flutter suite: **2077 passed, 3 declared skips**, exit 0. Skips: one opt-in native telemetry export and two macOS-only updater cases.
- Focused Flutter analyze: no issues. QA fault-boundary/assessment tests: 16 PASS.
- Final native Contracts: exit 0; main Python suite 1893 tests / 28 declared platform/opt-in skips. Those skips are not counted as physical/runtime
  PASS.
- Product-map parity, generated projection and ownership checks passed.

Native commands (retained outputs must not be overwritten):

- `python -m tools.qa.critical_client_acceptance.issue785_android_flutter_background_pair --device emulator-5582 --background-seconds 120 --output .out/matrix/api33-listener-r5`
- `python -m tools.qa.client_lifecycle.background_fault.run --device emulator-5582 --role sfu --output .out/matrix/api33-sfu-r5`
- `python -m tools.qa.client_lifecycle.background_fault.run --device emulator-5584 --role api --output .out/matrix/api34-api-r5`

## Native paired acceptance

Windows 11 x86_64; Flutter 3.47.7 / Dart 3.13.5; JDK21; targetSdk36. Dedicated headless x86_64 AVDs: API33/API34 Google APIs, API35 existing AOSP QA.
API33 `BOOHTACORD_QA_785_API33` / 5582; API34 `BOOHTACORD_QA_785_API34` / 5584; API35 `BOOHTACORD_QA_R1_1121` / 5580. Independent Chromium
participant, owned disposable Go/PostgreSQL/LiveKit stack. No production service was paused. The legacy runners incorrectly hard-code
ARM64/API35/another AVD and clean product source; those fields are overridden by this environment and hashes.

| Case | Observed result |
| --- | --- |
| api33-listener-r5 | PASS_SCOPED: Home 120.000s; decoded delta 135.700s; same Room; app socket connected; zero microphone publications. |
| api34-listener-r5 | PASS_SCOPED: Home 120.000s; decoded delta 130.130s; same Room; app socket connected; zero microphone publications. |
| api35-listener-r5 | PASS_SCOPED: Home 120.000s; decoded delta 135.180s; same Room; app socket connected; zero microphone publications. |
| api33-sfu-r5 | PASS_SCOPED: SFU pause 15.111s; 7 fault samples; RTP recovery observed at 0.834s after verified restore. |
| api34-api-r5 | PASS_SCOPED: API pause 60.111s; 30 samples, +300 packets; maximum observed stall 0ms. |

Faults required verified local ownership, paused/restored Docker state and a silent direct health timeout. Receiver samples must be dense; API-only
fault must retain healthy advancing media; SFU fault must actually stop RTP and recover within 15s. Samples are about 2s apart: this is not a latency
distribution or acoustic quality measurement. Both fault runs retained Room/track with a connected app socket and active microphone FGS after resume; explicit leave
stopped microphone FGS. API34 service dumps also showed isForeground=true, playback type 2 and microphone type 128, each startForegroundCount=1. API35
playback type 2 was observed too. All three listener captures were inspected at source resolution: listener title, two participants, connected dock
and leave action visible; no unavailable notice. Long synthetic names use ellipsis; API35 has a gray system navigation area.

## Source binding

Canonical runtime root: `/root/.cache/boohtacord-785-canonical-20261128/.out`. Original files remain under `matrix/<case>/`; no runtime JSON or media
is staged. Hashes below use UTF-8 text with LF; bundle is SHA256 of sorted-key compact JSON of rows `{path,sha256_lf,lines}` in sorted path order,
excluding plan/receipt. Bundle: `7df81278b733399bcdc2387b094c7a09c24f24d5ea4deabf8c65af221aefb3b1`.

| Source path | SHA256 (LF) |
| --- | --- |
| `clients/flutter/lib/src/features/voice/background_playback/session.dart` | `855db6ed07d86d09b45307db3f0e3a24d07d35b64a93a82752d88e2d6b5e3952` |
| `clients/flutter/lib/src/features/voice/background_playback/sync.dart` | `34c86459296f4d8632226e8d905c0ed54410a78c2599eb6de3861c0281db10cf` |
| `clients/flutter/test/features/background_microphone/app_resume_frames_test.dart` | `4e4b964d414da0fe910f0ebb448a96560a4736e7face406d8efadf246f9dba56` |
| `clients/flutter/test/features/voice/background_playback/start_races_test.dart` | `1ea6a95548b8d29c8cb6095dc249f23f4136d4becbf1b1e0b30dd5c48e96e0eb` |
| `clients/flutter/test/features/voice/background_playback/sync_races_test.dart` | `4b787cb7a8ebacee4e42242c54d46a8f749f10c56a096b39c24d2f4076358da4` |
| `clients/flutter/test/test_support/app_resume_frames.dart` | `de8659fe74b0679b6bf11adbeff3052129f7fa1f96680ad015e6fb2681e739b7` |
| `clients/flutter/test/test_support/app_resume_wait.dart` | `929be7f60f6bbc224aa8cefe2771dd4ed83fc645a53112e2bfe6da4c9abdfadc` |
| `tools/qa/client_lifecycle/background_fault/README.md` | `cfdbb2add889ac3af0845e736c8331d8cacddfd69987a35446785b0abf66c3aa` |
| `tools/qa/client_lifecycle/background_fault/__init__.py` | `b74d67b25191102ff8f4b3f2b2d426a496927ecacf4cf7145041ba9b6b999b5b` |
| `tools/qa/client_lifecycle/background_fault/assessment.py` | `b55a699f62cded7cb01cd96e3221999763747170901be6d26abeab49f3e5b4f1` |
| `tools/qa/client_lifecycle/background_fault/exercise.py` | `6385bf5329653b246a897829ffefa4a849a9086423171d09b199ccc99f879206` |
| `tools/qa/client_lifecycle/background_fault/owned_pause.py` | `029c9f183cd1023b21eb0c63260469ae4fe0be7306d4ace93b83dadb53e5b83e` |
| `tools/qa/client_lifecycle/background_fault/run.py` | `9577530c95796b2375c79d7497f8b5fa380f29e1fdc0f74987609e11666150fc` |
| `tools/qa/client_lifecycle/background_fault/test_assessment.py` | `d9aeda2345224a80070ceb8e5d0a802a01d88cabebf98cc397cd217dd288e409` |
| `tools/qa/client_lifecycle/background_fault/test_owned_pause.py` | `79a7d6d71b541712f9f81f900537cda94db5b59f61dbde439a3f8e41ba79f1c9` |
| `tools/qa/client_lifecycle/background_fault/test_run.py` | `cce5d924ed36309b7d39cc0c906cc457749273c6f8584a5c30b25db9583b9eac` |
| `tools/qa/local_features/features.json` | `05dac2849374e42aa1173a9e4ed968cd227f0bf47421b7d7782d840a5afbb534` |

| Runtime receipt | SHA256 |
| --- | --- |
| `api33-listener-r5/result.json` | `35b2e946e01c32a7dad2540f02f7a3471a47b87fbac7058b2f63ef076a2d8799` |
| `api33-listener-r5/screenshots/issue785-flutter-listener-after-background.png` | `23fdc836bfae5abce410eefb94f783cc0463cac75ac026bf611d770f922107af` |
| `api34-listener-r5/result.json` | `4455c41d945a80c9e9a4db4492122b9efdbec939d0d50072b96976fae2381570` |
| `api34-listener-r5/screenshots/issue785-flutter-listener-after-background.png` | `c4ea6a68393fd0a28c1ecc19488cc5bb66c9c7367b1dc48a6e329b624e42b9b0` |
| `api35-listener-r5/result.json` | `fc4f119af97257d79b9c553350dcfbd2b5111538e802ee8ee04c68dd729f6ac0` |
| `api35-listener-r5/screenshots/issue785-flutter-listener-after-background.png` | `64f2f1a91cd07530328545ef9830b5eee24e170222e1f1d4b14c51699b60a907` |
| `api33-sfu-r5/raw/result.json` | `e75a8a530af80c100db650b557893e65ff581626d0b44abfe82f01211af94176` |
| `api33-sfu-r5/fault.json` | `72ebc888547729b571a16cb30142615122e50840367aa40c84004a319d71950d` |
| `api33-sfu-r5/assessment.json` | `932d619fe57d272a1a7f27800bd623d016c70afe2f551812a45a89367e129d01` |
| `api34-api-r5/raw/result.json` | `25d4debf9b54378567a6c3890cdf7be8269c94276372a40162a6625b229de63a` |
| `api34-api-r5/fault.json` | `b0069d0225d4bc87315463b89068f4d1ac1d9d93d74784ed4e1a4653dab0f07f` |
| `api34-api-r5/assessment.json` | `99cf7112c6085a75c24ffe217256da9b992a0966047c14284f602273579ba714` |

## Registered acceptance and delivery

Required six-feature rerun `local-features/20261128-013704`: 29/29 stages PASS, including both actual API/SFU widths and source stability.
Original `20261128-005924` remains FAIL (28 PASS / desktop rejoin FAIL); it is not overwritten. Full desktop diagnostic replay and 20 consecutive logout/login/rejoin cycles passed on unchanged Web product source.
The first Web rejoin failure is not explained or claimed fixed; retain that follow-up in #785. A voice-only selection was rejected before tests; the full required selection was retained.
Global gallery visual_review remains NOT_RUN. Three native and five component captures plus scoped actual Web captures were reviewed; no global screenshot baseline was approved.
Current registered report SHA256: 775530b72bf8d08e5b34d592bbc56655feb6f19203fe23f535fd05ad966630dc. Retained diagnostic report and loop log: `.out/issue785-desktop-rejoin-diagnostic` and `.out/rejoin-loop-r3.log`.
CI and merge results belong to the PR/issue update, not an advance PASS here.

## Open acceptance

Physical Android 60-minute audibility, real routes/networks/Doze/battery behavior, secure keyguard, full API33/34 notification/admission policy,
iPhone/iOS and mobile browser matrix remain NOT_RUN here. Emulator counters do not prove audibility or speech quality. No installed release or
production deployment is claimed.
