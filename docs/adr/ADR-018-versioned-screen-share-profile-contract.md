# ADR-018: Versioned screen-share profile contract

- Status: Contract accepted; runtime and physical acceptance remain open.
- Date: 2026-10-07
- Decision owner: Project engineering
- Scope: Web, Flutter, backend media-session boundary, and shared fixtures.

## Context

Web and Flutter currently have parallel profile tables and different capture and
encoding behavior. Requested quality is user intent; effective capture and RTP
encoding are limits; presented frames are observations. These are separate
facts. The existing source profile split is not proven to cause FPS loss.

## Versioned descriptor

`contracts/screen-share-profile-v1.schema.json` defines the strict v1 session
descriptor. The adjacent catalog preserves legacy profile IDs and bit/s caps,
defines unvalidated experiment candidates, and distinguishes current
source-derived behavior from the target policy. Shared fixtures are consumed by
Web, Flutter, and backend contract tests.

The descriptor contains schema version, motion/text mode, requested profile,
effective capture and encoding plan, codec/layers, profile revision,
capabilities, bounded reason codes, and scope. Scope is origin, account, room,
logical media session, publication generation, and operation revision. These
IDs correlate a session and are not metric labels. The descriptor deliberately
does not contain presented FPS, network observations, or a claim that the
requested profile was achieved; those belong to separately sourced observation
records. `profile_revision` increments only on a profile transition and is
independent of the operation revision.

Publisher and viewer states are bounded enums. A stop, revoke, or logout first
invalidates the operation revision; terminal actions win over pending capture,
publish, profile update, and retry. A completion can publish only when its
session, generation, and operation revision are still current. Failure rolls
back screen tracks acquired by that attempt while preserving microphone and
voice membership. A signaling retry may continue its current operation; a new
publication generation identifies a new track. Reconnect can reuse valid
capture. Capture loss requires a user-visible restart, while a new user start
creates a new logical media session.

## Profile and transport policy

The target baseline is one selected remote video stream and one encoding layer.
Simulcast is separately enabled, explicit, and limited to two layers. Current
source-derived platform behavior remains recorded as unvalidated compatibility
data until publisher adapters roll out the independent feature switches. The
product requested default remains the compatible `P1080_60` profile from
REQ-SCREEN-01; current Web/desktop and mobile defaults differ and are recorded
separately in the catalog for follow-up adapter work. This is a requested
target, not a promise that a device can capture or present it. The
LiveKit/WebRTC SDK owns fast congestion adaptation. The app does not set a
mandatory minimum bitrate or emit periodic keyframes; it changes the target
profile only after explicit user choice or through a separately enabled slow
supervisor. That supervisor is off by default; if enabled, it uses ten-second
windows, three consecutive windows, and a 30-second minimum dwell. Layer caps are in bit/s. Summing active layer caps and transport
overhead is separate from reporting measured wire bitrate. The SDK also remains
the sole Dynacast owner; the app does not run a competing fast layer-selection
loop.

Existing `P{resolution}_{fps}` IDs and publication names remain readable.
Unknown descriptor versions leave the legacy track readable and disable v1
controls for that publication generation. Fallback is attempted at most once;
it does not republish and cannot create a downgrade loop. Descriptor metadata,
experiment profiles, and bounded simulcast have independent rollout switches.
The existing 1440p60 legacy profile remains readable; new 1440p60 use is
research-only until paired measurements exist. Native video-only capture does
not promise system audio.

Candidate targets are motion 720p60 at 3–4 Mbit/s, motion 1080p60 at 6–8
Mbit/s, and text 1080p15–30 at 2.5–5 Mbit/s. These are unvalidated experiments,
not device support or capacity claims. Geometry preserves aspect ratio, never
upscales, and selects the largest even encoded dimensions within the target.

## Reproducible acceptance method

The proposed gates are p05 presented FPS ≥55 for moving 60-FPS content, p95
first-frame and profile-switch latency ≤2 seconds, and no unexplained foreground
freeze over 500 ms. Each baseline run warms up for 30 seconds, then records 180
seconds in one-second windows; five repeats are required, with at least 120
valid moving-content windows per run. Collect at least 20 first-frame samples
and 20 profile-switch samples per run. FPS counts frames actually presented by
the visible remote renderer, never capture settings, `maxFramerate`, or local
preview. Measure each latency pair on one participant's monotonic clock, from
selected subscription or acknowledged profile switch to a frame presented.

Predeclare the moving-content interval. Exclude warm-up, static intervals,
hidden/minimized viewers, and intentionally paused publishers; retain unexplained
stalls in foreground moving windows. Compute a one-sided 95% confidence bound
for p05 FPS and p95 latency. A bound overlapping a threshold is inconclusive,
not PASS, and needs more repeats. Run degraded-network recovery separately,
prioritizing voice continuity over 1080p60. This protocol is proposed; it has not
been executed and does not establish a runtime or hardware PASS.

## Ownership

| Concern | Single writer / authority |
|---|---|
| Capture | Platform capture driver creates/releases tracks and applies capture limits. |
| Sender | Publisher adapter applies the encoding plan; SDK owns congestion adaptation. |
| Publication metadata | Publisher adapter writes one descriptor for the active generation. |
| Subscription | Selected-stream viewer owns one remote video subscription and switches old before new. |
| Rendering | LiveKit renderer presents the selected track and reports only available observations. |
| Authorization and revocation | Backend ACL and media-session lease; backend never proxies media or asserts presented FPS. |

Implementation-specific publisher ownership is delivered by SS-04/SS-05. This
ADR fixes the shared contract and fixtures; it does not claim the current
runtime, SFU negotiation, physical devices, or proposed quality gates passed.

## 2026-10-09 rollout amendment (#176)

Client publishers now default to one layer. Bounded Web and Flutter desktop
simulcast require independent explicit build switches; Android/iOS stay single
layer. Native backup codec is disabled. The catalog records these current source
defaults without asserting physical acceptance. Independent descriptor and HTTP
JPEG switches, safe VP8 fallback and per-origin/account native preferences are
defined in `docs/runbooks/screen-media-rollout.md`. Applied slow adaptation and
experimental profile enablement remain gated by calibration and pilot evidence.

## 2026-10-13 explicit content scenario clarification (#328)

The existing legacy `P{resolution}_{fps}` IDs carry resolution and frame-rate
intent; they do not encode motion/text content. The schema already permits
either scenario for these IDs. Go, Web and Flutter validators must accept that
explicit choice instead of inferring text from 30 FPS or motion only from
60 FPS. Named experimental profiles retain their catalog scenario constraints
and remain gated; this clarification adds no profile IDs or hardware claims.
New native publisher metadata takes mode from a visible user scenario choice.
Capture configuration, fresh sender-parameter readback and measured frame
cadence remain distinct facts. A missing confirmed configuration keeps the
native writer pending; selected values or desktop defaults cannot fill it.
