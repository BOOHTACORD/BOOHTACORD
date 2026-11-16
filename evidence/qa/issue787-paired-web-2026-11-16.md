# Issue #787 — paired Web telemetry follow-up (2026-11-16)

## Scope

Continued PR7 after #814 merged. This change closes defects found while running the paired Web sender → Web viewer flow: late LiveKit room-name availability prevented descriptor-based selection; measured bitrate could be fractional while the V1 envelope requires integral bps; and the receiver diagnostics panel did not reposition after asynchronous sender metrics changed its height. The paired real-stack observer now verifies the sender telemetry HTTP responses and the realtime delivery event as well as the displayed selected-stream sample.

No API contract, server ACL, media transport, or Flutter implementation changed in this follow-up. Go does not proxy RTP/RTCP or media payloads.

## Verification

- Focused Web Vitest: 4 files / 14 tests PASS for receiver panel, placement, sender envelope and viewer metadata; an additional focused run of sender envelope, metadata and registry passed 3 files / 15 tests.
- Focused Playwright regression for repositioning an open diagnostics panel after receiver metrics arrive: PASS.
- `node --test tools/qa/critical_client_acceptance/roster_websocket_observer.test.mjs`: 2 tests PASS.
- Paired real-stack critical journey: PASS at 1440 px. The run used `DOCKER_CONTEXT=colima-boohtacord`, `BOOHTACORD_QA_EGRESS_PLATFORM=linux/amd64`, portable proxy mode and isolated QA services. Screen-share summary: sender descriptor HTTP 204; six sender telemetry POST responses HTTP 204; one `screen_telemetry.updated` event observed. The selected viewer displayed fresh Web sender telemetry, measured 640 × 360 resolution and the distinct configured 720p / 30 FPS target. Stop-share and subsequent chat recovery also passed.
- Registered local-feature gate, report `.out/local-features/20261116-093434`: Web unit, build, accessibility, control consistency, member roster, mini player, share UI, track-name, voice interface, disconnect notice, real-stack 1440 px, real-stack 393 px, and source-stability stages PASS. Overall status remains **BLOCKED** because `web-screen_profile` reports one skipped publisher/viewer test.
- Manual visual review at source resolution is recorded in `.out/local-features/20261116-093434/visual-review.md`; desktop layout is in bounds and the mobile bottom sheet scrolls to its lower sender details.

Exact real-stack critical command:

```sh
DOCKER_CONTEXT=colima-boohtacord-qa BOOHTACORD_QA_EGRESS_PLATFORM=linux/amd64 \
python3 -m tools.qa.client_lifecycle.run --critical --portable-proxy --width 1440 \
  --output-root .out/local-features/issue787-paired-web-final-pass-20261116
```

## Remaining acceptance gates

- Flutter Android/iOS/macOS/Windows sender → Web viewer paired runs and supported-device/browser capability evidence remain **NOT_RUN**.
- Native/system capture-picker acceptance remains **NOT_RUN**.
- Hardware/network media-quality and load/capacity evidence remain **NOT_RUN**; this run makes no media-quality or capacity claim.
- The broad Web `screen_profile` publisher/viewer scenario remains **BLOCKED** by one skipped test.

Keep issue #787 and PR7 acceptance open until these gates have evidence. The machine-readable report status is intentionally unchanged; the visual notes do not convert the blocked gate into PASS.
