# Issue #787 PR7 — Web viewer telemetry aggregation

## Implemented behavior

- Web requests the negotiated `screen_telemetry_v1` capability and validates the versioned event and bounded `ScreenTelemetryEnvelopeV1` before dispatch.
- The viewer retains telemetry only for its selected remote publication with a sharing descriptor whose owner lease, media session, and generation match the envelope. Sequence and `server_received_at` order reject replayed/out-of-order samples. A bounded 15-second TTL uses the viewer's monotonic clock after receipt; the implementation never compares wall clocks from separate devices. Disconnect, selection change, unpublish, and publication-generation change clear the current sample.
- `ScreenReceiverDiagnosticsPanel.vue` labels receiver-local rows separately from sender rows, keeps target configuration separate, identifies configured values, shows sender freshness/platform, and omits unsupported sender measurements. `DiagnosisPanel` remains the playback/recovery diagnostic.
- The event remains ephemeral; no media payload, persistent storage, or extra LiveKit subscription is introduced.

## Verification

- Focused Web Vitest set (telemetry parser/store, receiver panel, realtime parser/URL, workspace dispatch and socket lifecycle): **31 passed**.
- Full Web unit suite from the registered runner: **583 files / 2,013 tests passed, 0 skipped**.
- `vue-tsc --noEmit -p clients/web/tsconfig.json`: **PASS**.
- `python -m tools.ci.native.contracts`: local run **BLOCKED** by host prerequisites/tooling (missing `cmake` and `jsonschema`, Go build-cache permission denial, and an incompatible Docker wrapper CLI); the broad runner reported 1 failure and 60 errors among 1,749 tests. PR7 does not modify contracts or backend producers. The required hosted `CI / contracts` job must pass before merge.
- `screen_share_ui` browser suite, including selected sender telemetry, provenance, receiver separation and expiry: **PASS**. Isolated focused run: 2 tests passed.
- Authenticated Web real-stack lifecycle: **PASS** at 1440px and 393px; owned services were cleaned up and Tempo verification passed. These scenarios do not pair a real telemetry sender with a viewer.
- Registered feature command:
  `BOOHTACORD_QA_EGRESS_PLATFORM=linux/amd64 ./tools/qa/local_features/check.sh --feature screen --feature voice --feature connection_status --feature shell --feature auth --feature chat --feature screen_metrics --feature screen_track_name --feature idle_afk --platform web --base origin/master --real-stack`
- Report: `.out/local-features/20261116-074633/report.json`. All selected stages passed except `web-screen_profile`, which is **BLOCKED** because one pre-existing publisher/viewer test is skipped. `source-stability` passed for `f6d22b348e705f8ca5a6c8d50b7a7c11b540868e worktree-sha256=96170fe446b37858a68281e435218b2aae4bde0463a3b59b90f304771f70c918`. The evidence note and PR7 `parity_review` records for overlapping features were added after the run. Those registry edits record platform decisions only; they do not change the selected feature IDs, focused tests, acceptance commands, or scenario assertions used in the run.

## Source-resolution visual review

Reviewed the captured PNGs at their native pixel dimensions:

- `images/web-screen_share_ui/disclosure.browser-selecte-9fb92-es-from-server-receipt-time/sender-telemetry-393.png` — 393×900.
- `images/web-screen_share_ui/disclosure.browser-selecte-9fb92-es-from-server-receipt-time/sender-telemetry-1440.png` — 1440×900.
- `images/web-screen_share_ui/disclosure.browser-receive-222f1-eps-unknowns-in-diagnostics/receiver-diagnostics-320.png` — 320×900.
- `images/web-screen_share_ui/disclosure.browser-receive-222f1-eps-unknowns-in-diagnostics/receiver-diagnostics-1440.png` — 1440×900.
- `images/web-screen_share_ui/disclosure.browser-200-tex-7b1d5-rds-intact-at-desktop-width/receiver-text-200-1024.png` — 1024×900 at 200% text scale.

Observations: the narrow diagnostics sheet fits the viewport and its content scrolls vertically; receiver and sender sections remain separate. The desktop view keeps both summary groups readable. Sender resolution/FPS are marked measured, configured bitrate is marked configured, and no sender RTT or packet-loss row appears when the sender reports those values unavailable. The 200% capture retains readable labels without a horizontal overflow. Browser assertions also confirmed sender values disappear after the 15-second TTL.

These screenshots prove the fixture presentation only; they do not prove paired media telemetry delivery or physical-device acceptance.

## Remaining acceptance status

- Web sender → Web viewer on a paired live publication: **NOT_RUN**.
- Flutter Android/iOS/macOS/Windows sender → Web viewer paired runs: **NOT_RUN**; see [PR6 sender capability matrix](issue787-sender-capability-matrix-2026-11-16.md) for platform field availability evidence and limitations.
- Hardware/media-quality/network/capacity claims: **NOT_RUN**.
- The issue remains open until the skipped screen-profile gate and paired platform acceptance have evidence.
