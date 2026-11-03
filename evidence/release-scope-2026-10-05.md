# Grouped release acceptance — 2026-10-05

Status: PASS — automated release acceptance and delivery complete.
Native snapshot: e2b19dfef3568eb00187c5dd35e244aa58ae2942, version 1.0.32+46.
Installed Web/API/catalog: c860642f59d9c9538878d89b33a0e6639710e2ae.
Later 8891a5e8 changes tests/backlog/docs only; production sources are identical.
This packet does not claim physical media, capacity or complete design acceptance.

## Integration and repairs

Active GitHub branch histories are integrated into master. Retired pre-migration
histories remain in local codex/release-archive-integration-2026-10-05: GitHub
rejects their historical APK blobs above 100 MB. ADR-011 canonical sources win.
The primary checkout retains existing uncommitted/untracked work.

- Fixed the Go guild handler compile error and singleton/migration test fixtures.
- Preserved Web receiver union handling and native physical-key lookup behavior.
- Added native DSP CTest to the normal Web gate; actual two-browser LiveKit tests
  use synthetic microphone PCM for reconnect, selection, mute and deafen.
- Restored generated Windows plugin CMake before provenance collection; explicit
  microphone float conversions preserve MSVC /WX compilation.
- Actual voice notice checks exposed a missing default live announcement;
  corrected the Vue boolean default and verified reason-specific semantics.
- Actual 1.0.30 APK codes 1044/2044/4044 exposed an updater identity conflict.
  Six failing Dart cases and five publisher rejection cases established it.
  Explicit ABI offsets preserve universal/Windows equality and reject wrong
  architecture, base and malformed values. Publication now inspects actual aapt
  versionCode/native-code and signer before accepting the APK manifest.
- Two intermittent first-audio-case timeouts required native Vite HTML processing,
  explicit fixture entries and named bounded RPC/readiness steps. Cleanup errors
  remain fatal after successful assertions; primary failures remain visible.
  No retries or relaxed PCM assertions. HTML regression failed before repair and
  passed afterward; six cold starts, 12 strict cleanup repetitions and four
  repaired input cases passed. A local full-audio attempt lacked its SFU tunnel
  and generated WASM: retained as an environment failure. CI rebuilt prerequisites
  and passed the complete browser gate. Temporary SFU/tunnel fixtures were stopped.

## Automated acceptance

[Full exact-source master CI](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/37257800695): PASS on e2b19dfe.
[Frozen candidate CI](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/37256830533): PASS on the same source/tree.
[Final server build gates](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/37259679296): PASS on c860642f.
[Additional test-only CI](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/37259836134): PASS on 8891a5e8.
The c860642f general CI was superseded by 8891a5e8; its cancellation is not PASS.
The new fixed-chrome Android scroll regression also passed locally.

| Gate | Result |
| --- | --- |
| Go test / vet / build | 985 passed, zero skips/failures |
| Web unit / types / build | 1045 passed |
| Playwright | 36 cases, including actual two-browser LiveKit PCM |
| Native DSP | three CTest cases |
| Flutter application | 585 passed on Linux and Windows |
| LiveKit / WebRTC vendor | 435 + 24 passed; one upstream skip |
| Flutter analyzer | zero errors/warnings; 36 existing nonfatal infos |
| Python native/contract checks | 106 tests on Linux |
| Contract / spec / dependency / workflow / rollout guards | PASS |
| Kotlin legacy + AGP builtIn Kotlin / debug APK / Windows release | PASS |

## Targeted issue acceptance and remaining scope

#103: both callback orders, stale/duplicate/pending leases, addressed PostgreSQL
kick publication, bounded semantic traces and actual notice components PASS.
#106: physical binding model, capture, account preferences, conflicts, editing/
IME/repeat/focus/modal guards, pending ownership and foreground actions PASS.
These results supersede earlier code-only NOT_RUN records for executed checks.
#104 password generator and #108 microphone selection were already closed;
their regression checks passed in the grouped gate.

Actual notice gallery: 24 PNGs, real production components with synthetic states,
Web 1440/1024 px and Flutter 390/1024 dp, loaded fonts. Notice component sources at
30d275cc remain unchanged at e2b19dfe. Copy, actions, live status and overflow PASS.
Local gallery: release-scope-2026-10-05/ACTUALS.html under this chat's visualizations.
These captures do not prove a physical OS/device admin kick or acoustic quality.
Physical media remains NOT_RUN; broader #62/#67/#82 acceptance gates remain open.

#100/#101 lack client guild/system-message integration. #102 retains production
trace/privacy acceptance. #105/#107/#110 retain device/quality work. Other incomplete
device, privacy, recovery, load and UI issues remain open; no 15 FPS/capacity claim.

## Delivery and provenance

[Android 1.0.32](https://github.com/BOOHTACORD/BOOHTACORD/releases/tag/android-v1.0.32)
and [Windows 1.0.32](https://github.com/BOOHTACORD/BOOHTACORD/releases/tag/windows-v1.0.32)
use clean e2b19dfe. All published bytes/SHA256SUMS/manifests match; Windows ZIP
members, sizes and hashes match both embedded and external manifests.
Android version codes: armv7 1046, arm64 2046, x64 4046. All three actual published
metadata identities evaluate up_to_date through the production Dart evaluator.
Signer SHA-256: 394e369de2d566b4897493ee498da2f27745e514c49ca88c6489b0b0a811212b,
unchanged from prior releases. Windows retains the existing unsigned policy.
Immutable 1.0.30/1.0.31 artifacts are retained; identity defect rolled forward.

Catalog CAS 19 to 24 promoted five verified r46 selectors only after publication;
iOS/macOS remain unconfigured. c860642f changes only the catalog after e2b19dfe.
[Canonical signed build](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/37259679296)
and [production installation](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/37260016097): PASS.
Read-only production verification: health OK, build-info 1.0.32/r46, source/body
receipt hash, served RNNoise WASM/MIME/SBOM/license plus missing-asset 404 PASS.
All five public selectors return revision 24/r46 with no-store and nosniff.
Installed receipt and both running container image IDs match c860642f:

- API: sha256:9f6f8e41d0890f026e58905b6befa24d824f113810759cb627ad1971b6bd7d0a
- Web: sha256:2a676ab50c55186b8e470a374af954a93d08675d409a11d8b194a7faa80bcec3

Machine verification JSON, native manifests, asset hashes, evaluator logs and
visual hashes are retained in this chat's release-scope-2026-10-05/proofs directory.

Slavik Gym report: route=review_gate; packet=release-finalization;
tokens=estimated:18000; method=manual_estimate; driver=native-CI-and-receipts;
next_split=physical-device-acceptance.
