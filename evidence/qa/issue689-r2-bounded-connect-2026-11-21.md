# Issue689 R2: bounded connect and ready acceptance

Date: 2026-11-21. Status: **PASS_SCOPED** for Web, Windows and Android emulator
R2 transport faults. Base master: `8f358a9639c644208e57eb8f7177ce3ed812e35b`.
Companion JSON retains each actual run's immutable source-before/source-after,
measured samples, original PNG dimensions/checksums and native artifact hashes.
Individual QA overlays differ as acceptance was strengthened; native production
Flutter and backend inputs are unchanged from the base. Documentation, parity
notes and generated inventory were finalized after the runtime runs.

## Production defect and preservation

An actual Web `ready-stall` screenshot showed green "Чат подключён" and no retry
button after HTTP101, while actual `connection.ready` bytes were withheld.
Moved the Pinia owner into `realtime/connection_lifecycle` behind the original
three-line public re-export. The previous over-limit mixed controller was split
with session recovery; both production files stay below120 lines.
Before/after extraction, all94 existing realtime tests passed. Two new readiness
tests failed before the fix and passed afterward; the final96 tests pass.
Web now becomes CONNECTED only on typed ready, clears the error there and keeps
retry visible while opening. The unchanged15s total opening-to-ready budget is
not reset at upgrade; the14s upgrade regression expires at15s. Session checks
remain10s. Flutter production already had the correct readiness behavior.
Generated signal-catalog changes are only two producer paths/checksums following
the move; inventory still has301 signals. No schema/dependency/deploy changes.

## Actual runtime matrix

Owned Go/PostgreSQL/LiveKit/Caddy stacks, real timers, HTTPS and actual app sockets:
- Web: built production bundle, Chromium, `python -m tools.qa.realtime_connect.web.run --output .out/r2-web-final`.
- Windows: mounted production AppState/UI, `python -m tools.qa.realtime_recovery.native.run --scenario r2 --platform windows --device windows --flutter Q:/Codex/issue689-flutter-sdk-ntfs/bin/flutter.bat --output .out/r2-windows-run1`.
- Android: same runner with `--platform android --device emulator-5562 --adb Q:/Codex/pr693-android-sdk/platform-tools/adb.exe --output .out/r2-android-run1`; API35 x86_64 AVD.
- Four public faults: upgrade error, delayed upgrade, delayed snapshot and split
  upgrade/ready. Public owner suspend/unload cancels the actual held request.
- Six authenticated faults: upgrade error,20s upgrade stall,20s ready stall,
  split10s upgrade+20s ready,20s session stall and actual protected-API401
  delivered12s late after cancellation. Responses/frames are never synthesized.
- Auth opening-stall recovery: Windows15.75-16.16s, Android16.14-16.37s,
  final Web16.97-17.01s, including retry/network. Session recovery: Windows
  10.96-10.98s, Android11.17-11.23s, Web11.16-11.20s. Upgrade error is immediate.
  Proxy elapsed begins after API transit, so is shorter than the client's total.
- Manual retry cancels opening within5s. Logout cancels opening/session checks;
  same-owner reauthentication survives late401 without a cookie/identity reset.
  Real server-side logout outside client storage expires the current session.
- Native steady-state authenticated socket gauge is exactly2 at11 phases per
  run. During transient faults the same native room remains connected; Web dock remains healthy, participant
  card count is1 and roster recovery panel clears after every healthy phase.
- Public Web baseline3s and native10s budgets are preserved. Timeout never logs
  out a valid identity; only actual session revocation does. No SSE/polling.

## Visual review and evidence boundaries

Inspected all5 Windows1898x1024,5 Android1080x2400 and6 final Web1440x960 PNGs
at original resolution. Stalled views retain healthy voice and show orange chat/
roster recovery; final views have the expected participant/identity and no stale
recovery panel. Public fault views retain the usable login form. No new clipping
observed. Android's open drawer obscures part of main content; that part is not
visually accepted. The original Web ready-stall frame is retained as Before.
All final runtime reports have before=after source identity and owned cleanup.

Focused checks: Go6 behavior tests; Python6 fixture/runner tests; Node1 diagnostic
privacy test; Flutter15 deadline/late-scope tests and fatal-info analysis; Web96
realtime tests and production build; contract verifier29 tests, parity and source
catalog checks. Four late-success scope boundaries close stale sockets without
adoption/retry/expiry. R1 default Caddy config was byte-identical after extraction.
The Go fixture and Node privacy test are included in default Python CI discovery.
Hosted CI and broader canonical browser report are independent delivery gates.

## Preserved failures and limits

Proxy RED exposed delayed backend-close forwarding and an invalid artificial401
premise; fixed fixture-only logic, retained actual bytes/protected endpoint and
reran the real matrix. A native async cleanup test needed the callback turn.
Web initial SFU join failed once before any R2 fault; independent targeted probe
then connected in519ms over UDP. Root cause remains unestablished (R7 concern).
A later added roster check used a preview-only selector; the actual participant
card selector and fresh-panel assertion pass in the final full Web run. The
intermediate successful run's early final screenshot was not final roster proof.
Broad Linux checks initially lacked pinned Python dependencies; installation
resolved their10 focused tests. Actual generated catalog drift was regenerated.
Original FAIL/BLOCKED outputs stay intact; none was relabelled PASS.

Read-only production public socket baseline passed: actual101/ready/snapshot,
strict TLS and source receipt8f358a9. No production auth/session faults were
injected. Physical Samsung, Apple, OS storage, signed installers, audio quality,
capacity and long-duration stability remain NOT_RUN here. No manual server
deployment or full issue689/R3-R9 completion is claimed. Owned AVD was stopped;
user phone, other emulator, Windows client and shared fixture were preserved.

Broader canonical command selected connection_status/auth/chat/idle_afk/screen/
voice because the compatibility shim has shared registry ownership. Web2035
unit tests/build and the10 connection_status browser cases PASS; its original
320x720 recovery capture was reviewed without clipping. The overall report
remains FAIL: accessibility3, controls1 and DM1 startup failures, plus occupied
488x port setup failures for both critical widths. The exact browser failures
subsequently PASS with tracing and unchanged source/expectations; their original
failures are retained and startup root cause is not established. Screen-profile
19 PASS/1 previously skipped remains BLOCKED, not R2 media acceptance. Critical
viewport reruns and exact-head hosted CI are recorded separately at delivery.

Both exact critical viewport reruns now PASS (1440:182.04s;393 timings in JSON),
including actual API restart/persistence, telemetry and owned cleanup. Reviewed
their original chat-failed/media-connected captures: healthy voice remains, no
new clipping; narrow drawer obscures part of main content and recovery panel.

Full Linux `python -m tools.ci.native.contracts` exits0 after prerequisites and
inventory repair:1811 Python tests (27 platform/fixture skips), contracts and
traceability/workflow/dependency/Compose checks PASS. Skips grant no device proof.
