# Compact Web stream viewer

Task: DW-009; dependencies T-022, T-050, DW-003, DW-004, DW-008.
Base: `bd2c5f656abb6b027f7f67900247f833dafefc29` (`origin/master`).
Branch: `codex/compact-stream-viewer`.

## Changes

The video uses the available viewer height with 12 px outer padding. Playback,
fullscreen and stop controls share an overlay. Participants, multiple streams
and diagnostic tools open on demand without resizing the video. A single
selected stream has no duplicate thumbnail. Recovery diagnostics stay mounted;
errors and recovery actions remain visible independently of the idle toolbar.
Statistics render inside the browser fullscreen element when applicable.

At mobile widths, fullscreen and stop-viewing use labelled icons in the same
row as the remaining controls. Diagnostic tools are available through the
additional-actions menu. Existing keyboard focus visibility, touch controls,
reduced-motion handling and the pointer idle animation are preserved.

## Verification

- PASS: Web unit suite, 1622 tests / 487 files.
- PASS: production Web build with `VITE_PUBLIC_ORIGIN=https://localhost:4810`.
- PASS: registered Web browser suites in
  `.out/local-features/20261022-235159/index.html`, including all 36
  screen-share UI tests, accessibility, mini-player and responsive shell suites.
- PASS: final focused compact-viewer rerun, 10 tests. Includes outside-click
  and Escape dismissal, selection, idle recovery, fullscreen statistics and
  toolbar geometry at 320/390 px for local and remote streams.
- PASS: `python3 -m tools.verify.client_parity.run --base origin/master`.
- FAIL: the required local-feature command with `--real-stack` and Web scope
  initially failed both 1440/393 server journeys because the existing QA Docker
  profile was stopped. The original report retains FAIL.
- BLOCKED: after starting that profile, a separate 1440 retry built the Web
  client but could not build the API image: Docker buildx/BuildKit is absent,
  while the existing Dockerfile requires `RUN --mount`. Log:
  `.out/compact-viewer-real-stack-1440.log`. No server/media acceptance PASS
  is claimed. The 393 server journey was not retried after this shared blocker.
- NOT_RUN: Android/iOS runtime and physical-media acceptance. This change is
  limited to Web presentation; native clients retain their existing layout.

Command for the registered run:

```sh
./tools/qa/local_features/check.sh --feature shell --feature auth \
  --feature connection_status --feature screen --feature voice \
  --platform web --base origin/master --real-stack
```

## Focused visual review

Reviewed changed-viewer captures at their original raster resolution. In the
390/1440 compact-viewer fixtures the stage occupies 736 px of a 760 px room;
the synthetic 1280x720 source keeps its aspect ratio, with expected letterboxing.
The active controls form a single row and no permanent diagnostic, thumbnail
or participant row consumes video height. At 320 px, remote fullscreen,
stop-viewing, audio, pause, statistics and additional actions fit inside the
stage; active touch targets are 44 px. The loading fixture deliberately has no
media frames and is not evidence of playback.

The 390 px / 200% participant capture keeps the panel inside the viewport,
provides horizontal scrolling for participant cards and ellipsizes long names.
The close action remains visible. Escape returns focus to the panel trigger.
Original user captures explain the previous wrapping/layout problem; no new
screenshot baseline was approved.

The broader registry gallery was not individually approved: its machine
`visual_review` remains NOT_RUN. These observations cover the changed viewer
captures only. Generated screenshots and logs remain outside Git; this record
does not close an integration or release gate.
