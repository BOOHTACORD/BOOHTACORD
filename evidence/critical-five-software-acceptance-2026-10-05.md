# Five critical software issues — actual acceptance

Date: 2026-10-05. Executor/observer: Codex; synthetic owned fixtures only.
Scope: #56, #64, #79, #80, #89. PR: [128](https://github.com/BOOHTACORD/BOOHTACORD/pull/128).
Status: PASS for the isolated scenarios below. Native CI passed on the candidate;
the compatible production rollback requirement of #89 remains NOT_RUN.

## Source and environment

- Browser candidate: `0e44ded1f7e76dad1d527d8d248413ce407a951e`.
- Backend tree: `94f74f1450236b2575267fe136f9edbda6d9cf83`.
- Web source tree: `b9f6cbd1ee0abfbcf49f83cb3fe0faa30ade3077`.
- GitHub-tested merge: `23eef8c45412d098febe5aefa1846ea92c615806`;
  its backend, Web source and installer trees match the candidate exactly.
- Upload run: `38abc36702ceded3079ee6bab74991927706bf10`; its backend,
  upload fixture and installer production trees are unchanged in the candidate.
- Linux Docker, Node 22.23.3, locked Playwright, real production Vue build,
  PostgreSQL 17.6, actual Go API, Caddy internal TLS and Tempo 2.10.3.
- Real LiveKit 1.13.7 image digest:
  `sha256:6fd3b7088874c4d119160dd688798dfec852bc014786d392caad15f6f63912a3`.
- Fixture SFU/Chromium explicitly permit loopback ICE; native RTCPeerConnection
  states are observed, not replaced. REST responses and SDK are not mocked.
- Accounts, channels and data belong only to labeled disposable fixtures;
  production history, users, volumes and configuration are untouched.

## #64 — authentication

Actual register succeeds, only its subsequent login transport is interrupted.
The UI confirms account creation and retries login manually: exactly one register
request, unchanged Unicode/spaces in the password. Show-password and admin-reset
explanation are accessible. Actual reset completes; used and DB-expired links
are rejected, focus is correct and token fragments disappear. Native rate limiter
returns 429; the UI displays Retry-After and makes no automatic retry.

## #79 — independent connection status

Two actual listener clients establish WebRTC connections. Closing only the native
chat socket leaves media connected and shows separate chat/voice states. Targeted
chat retry recovers. Stopping only the owned SFU shows unavailable roster with
last successful age and no false empty-room state; targeted roster retry recovers.
Logout and native own-session revoke clear chat, voice and roster; old cookie
returns 401. Lease revoke is exercised while a protected GET remains blocked.
The native 15-second server notification poll and client disconnect latency are
measured separately; no physical audibility or capacity claim is made.

## #80 — protected refreshes

Before: exact previous native Web built from Git archive and connected to the
real API: remote `a326f4f8`, final CI `eb7c69d4` (same Web source).
Active/hidden counts are retained for bursts of 1/20/50 actual POST-generated hints.
Remote maximum simultaneous GET/resource before: 1/5/3; after: at most 1.
Final CI active history GETs before/after: 1/1, 20/3, 50/4 at both widths;
before maximum parallel/resource 1/4/3, after 1/1/1.
Hidden conversation history GET count remains zero. Transactions may span more
than one coalescing window; the claim is per-resource concurrency, not one HTTP
request for every arbitrarily timed set of 50 transactions.
Native tests additionally prove short-window N-to-1 coalescing, dirty follow-up,
revision 50, durable replay after failed refresh/revoke, and immediate lease revoke.
Actual older loaded message edit renders revision 2 and subsequent delete renders
its tombstone. Retained TEXT revisions stay idle behind an active DM.

## #56 — attachment reservations

The exact attachment tmpfs volume is sampled with statfs and real metrics while
two actual multipart uploads are held. Normal capacity is 8 GiB, with an independent
Go rebuild running during active samples. Reserved bytes transition through
0 → 25,000,000 → 50,000,000 → 25,000,000 → 0 after cancellation and completion.
Headroom is checked against two protected reserves, max upload and in-flight bytes.
The separate 2 GiB + 51,000,000-byte capacity-limited fixture returns 507 for a third
upload. Cancellation releases reservation; completion and retry return 201.
Final reserved bytes and staging file count are zero in both scenarios.
This is an actual isolated reservation/load proof, not production disk capacity
or the 100-participant capacity gate.

## #89 — single writer

Actual second API startup on the same volume is rejected before serving requests.
Each fixture completes two stop-first API process handover cycles. SIGTERM shutdown
must finish without exit 137; the old container is gone before its successor starts.
OS tests also prove independent-process exclusion, crash release and repeated-close
safety; Windows LockFileEx and Linux flock are covered by native Go runs.
Compose declares one replica and stop-first update/rollback. Native verification
and the signed installer/rollback preflight reject scale/replicas >1, start-first
and multiple running writers before the guarded rollout.
These process cycles use one API binary. They do not substitute for the compatible
distinct signed release rollback and live volume identity rehearsal in QA-12.
Keep #89 and QA-09/12 open until their original acceptance is fulfilled.

## Checks and retained artifacts

- Local full Web: 354 files / 1125 tests PASS; TypeScript/Vite build PASS.
- Python: 142 tests PASS, one existing platform skip.
- Contracts, 39-requirement traceability, documentation links, workflow routing
  and single-writer topology checks PASS. Native CI receipts are recorded below.
- [Autonomous GitHub acceptance](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/37344793739)
  PASS: real browser at 1440/1024, baseline, uploads and writer handover.
  Local disconnect after lease hint: 5/4 ms; server hint wait: 3858/3860 ms.
- [Native GitHub CI](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/37344794829)
  PASS: contracts, Go/PostgreSQL test/vet/build, full Web/audio/browser, Flutter
  analyze/tests/Android build modes/debug APK and Windows build inspection.
- A later cold audio fixture startup exposed a module readiness timeout. The
  fixture now returns 503 until all modules/static imports are warmed; three
  Node regression checks pass. Audio assertions and timeouts are unchanged.
- Local safe reports/screenshots: `C:/Users/egkur/.codex/visualizations/2026/10/05/critical-five-issues`.
- Upload report `upload-reservations-graceful.json` SHA-256:
  `aa455bc0b4fab5ec4990b85c3f03c8575def51f273d66b0a2ca191a27d5ec33c`.
- Baseline report `refresh-baseline.json` SHA-256:
  `da2fb098c9dc21f31a3b238375439d894252b79ae18d7500a71f287b1535f97e`.
- Each report binds actual source files, screenshots and API binary hashes.
  No cookies, tokens, account IDs, message bodies or payloads are retained in reports.
- Owned database, SFU, proxy and volume fixtures are removed after each run.
- Final CI reports/screenshots: `ci-0e44ded1/client-lifecycle/{1440,1024}`;
  both reports bind merge `23eef8c4`. Their upload report SHA-256 is
  `f59e5b3fa30480e824d33c24a1647c87a45dff717b5fde014db3c46a344c0403`.

Full QA-03/05/09/10/12/13, physical Android/Windows/macOS media acceptance and
production release approval retain their original status. These scoped proofs
do not close their broader device, privacy, load or compatible rollback criteria.

Follow-up: [notification batch preservation](notification-coalescing-preservation-2026-10-05.md).
