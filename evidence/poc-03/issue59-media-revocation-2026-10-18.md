# POC-03 / QA-10 / T-006 — actual media revocation — 2026-10-18

**PASS: all seven actions, two independent browser media clients, actual
received video/audio, confirmed SFU removal and both old credential classes.**
This closes the runtime gap tracked by #59. The earlier BLOCKED preflight is
retained as history. Application, API and production proxy source are unchanged.

## Candidate and isolated environment

- Application/API source: `63a44c264fa3fdeb0a660622dd5ab573ca70160d`.
  Exact backend tree, QA script hashes and running container image IDs are in
  the [machine receipt](issue59-media-revocation-2026-10-18.json).
- Physical host: macOS 27.0.1 ARM64. Two independent Chromium 153.0.8010.12
  contexts with distinct secure-cookie sessions; a third administrator session
  issues actual API mutations. This is browser transport acceptance on one Mac.
- Locked LiveKit JavaScript SDK 2.22.3. Actual SFU:
  `livekit/livekit-server:v1.13.7@sha256:6fd3b7088874c4d119160dd688798dfec852bc014786d392caad15f6f63912a3`.
  Running SFU image ID is recorded separately from the manifest digest.
- Existing owned Go/PostgreSQL 17.6/Tempo 2.10.3/Caddy 2.10.0 fixture, tmpfs
  database/storage, loopback-only published ports. Production Caddy `/rtc`
  forward-auth is retained; only owned upstream names and static test serving
  differ. RoomService remains inside the owned network. No production mutation.
- Moving synthetic 640×360 canvas and quiet 440 Hz tone; real WebRTC transport,
  actual API secure-cookie/Origin handling, durable database outbox and worker.
  No mocked API responses, media receivers, disconnections or worker results.

## Required observations — all PASS

| Action | Positive API / SDK handshakes | Old API / SDK replay | Old lease credential | Prior cookie on protected API | Observer |
| --- | --- | --- | --- | --- | --- |
| Voice kick | 101 / 101 | 403 / 403 | 409 | 200 | Connected, lease valid |
| Ban | 101 / 101 | 403 / 403 | 401 | 401 | Connected, lease valid |
| Logout | 101 / 101 | 403 / 403 | 401 | 401 | Connected, lease valid |
| Session revoke | 101 / 101 | 403 / 403 | 401 | 401 | Connected, lease valid |
| Password reset | 101 / 101 | 403 / 403 | 401 | 401 | Connected, lease valid |
| Voice transfer | 101 / 101 | 403 / 403 | 409 | 200 | Connected, original lease valid |
| Close voice channel | 101 / 101 | 403 / 403 | 409 | 200 | Both leases revoked, room empty/finalized |

Before every action the receiver shows decoded frames and inbound audio packets.
After every action the presenter disconnects, both received tracks unsubscribe,
and the database records the worker's confirmed SFU dispatch. The record includes
UTC action times, actual HTTP statuses, packet/frame counts, worker attempts and
action-to-removal duration for each case. Other than channel close, the observer
retains its connection and can still obtain a credential for its original lease.

The SDK credential comes from the real `tokenRefreshed` event and differs from
the API-issued credential. Both are checked as unexpired before the final replay.
The **same raw TLS WebSocket probe** must first receive 101 while admission is
valid and later 403 after authoritative revoke. Positive probes happen before
publication because another connection with the same identity replaces the SFU
participant; the final SDK connection and actual receiving-media precondition
are established afterward. Thus a malformed probe or an expired credential cannot
masquerade as successful enforcement.

Kick permits an explicit new lease and real SDK connection without reviving the
old credential. Transfer creates a distinct lease/room and accepts its new SDK
connection. Ban denies login; reset-link reuse returns 400. Closing the channel
reaches room-empty/finalized with zero pending revocations.

Observed action-to-media-removal times: **11.935–13.632 seconds** on this fixture.
The current production worker polls every 15 seconds. The harness's 45-second
observation guard is not a new product SLO or a claim of immediate disconnection.

## Repeatability, privacy and visual review

The source-bound final run passes with the committed controller, browser/client,
request, proxy and validator file hashes. Earlier diagnostic attempts exposed
fixture issues: missing expected-account header, using optional `/auth/session`
as a stale-cookie probe, and the normal 10-logins/5-minute source quota. The runner
now supplies the expected actor, probes protected `/me/sessions`, and honors one
bounded numeric `Retry-After`. The final run waited 211 seconds; limits and source
identities were not altered. An interrupted hardening run is not accepted evidence.

All **14 original 900×600 synthetic screenshots** were visually inspected. Each
before image shows the received canvas; each after image shows detached video.
The observer stays connected for individual revocations and shows disconnected
after channel closure. These are SDK fixture captures, not product-UI or subjective
audio-quality acceptance. Capture hashes are in the JSON; generated PNGs remain
in ignored `.out/issue59/`, not Git.

Credentials/cookies, reset links, account/room/lease/session identifiers, HAR,
query URLs and raw SDK logs are absent from public evidence. Probe credentials
exist only in memory. The raw TLS probe trusts the owned Caddy CA; the disposable
browser uses an explicit local certificate-error exemption, so production TLS
trust-chain acceptance is not claimed. All owned services, private fixture inputs
and build resources were removed. Foreign services were preserved.

## Validation and reproduction

- Eight new Python regressions PASS; one invokes five Node request-contract
  regressions. Three existing real process-group cleanup tests also PASS.
  The receipt validator rejects missing cases/media, duplicate rows, incomplete
  results, expired/unobserved credentials, missing positive controls, observer
  loss and unapproved fields. Focused checks were added before implementation.
- Nearest Go media-admission, revoke-dispatch and RoomService client tests PASS.
- Spec traceability: **PASS_INDEX_ONLY**, 39 requirements; approved Windows brief
  unavailable on this Mac. No API contract change.
- Reproduce with `python3 -m tools.qa.media_revocation.run`; prerequisites,
  isolation and bounded cleanup are in the
  [runner instructions](../../tools/qa/media_revocation/README.md).

Final exact-head CI and master merge are recorded in the PR and issue after this
evidence commit. They are not asserted as completed in this pre-merge record.
Physical capture/FPS, acoustic quality, capacity and production rollout gates are
outside this POC-03 enforcement acceptance.
