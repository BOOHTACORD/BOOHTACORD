# Flutter compact screen-viewer participants — 2026-10-24

**Scope:** Match the recent Web compact participant panel in Flutter screen viewing. The active stream uses the available stage height; its roster and watcher count open in a dismissible overlay in the room and fullscreen. Ended-stream layout keeps its existing participant footer.

**Base:** `4b8a48e6540207e4e0082ed735af8a0700d687a0` (`master`)

## Results

- Focused Flutter participant-panel tests: **PASS** (2 tests), covering the full-height room stage, opening and closing the roster, footer preservation after a stream ends, and opening the panel in fullscreen while transient actions are hidden.
- Flutter full unit suite: **PASS** (1,640 passed; 1 skipped).
- Registered Flutter component captures: **PASS** (338 tests).
- Dart analyzer on changed Flutter files: **PASS** (no issues found).
- Registered Web unit/build/browser checks: **PASS** in `.out/local-features/20261024-212416`; Web unit suite reports 1,630 tests across 489 files, and `screen_share_ui` reports 38 passed.
- Real API/SFU stages: **BLOCKED during environment setup**. Both viewport runs failed before starting services because the `colima-boohtacord-qa` Docker socket was unavailable; Colima reported the profile `Broken`, and no Lima instance was present. No live stream was created.
- Android and iOS runtime checks: **BLOCKED**; no owned QA emulator or simulator is configured.
- Native live-stream acceptance: **NOT_RUN**. Widget coverage and fixture captures do not prove native media playback.

## Visual review

Inspected the changed Flutter captures at their source resolutions in `.out/local-features/20261024-213054/flutter-captures/`:

- `voice-viewer-participants-room.png` and `voice-viewer-participants-room-open.png` (900 × 640): the roster button and popup overlay the video stage; no 92 dp row remains below the active stream. The title, watcher count, close control and participant card fit without clipping.
- `voice-viewer-participants-fullscreen-open.png` (390 × 844): the fullscreen title remains visible, and the participant menu opens while the transient action layer is hidden. The menu stays within the portrait viewport.

Inspected Web's `compact-viewer-390.png`, `compact-viewer-1440.png` and `compact-participant-panel-653.png` in `.out/local-features/20261024-212416/web-screen_share_ui/`. The Web reference keeps video across the stage and opens the compact roster over it. Flutter follows the same layout intent. Captures use synthetic stage content; they do not show decoded live media.

The changed screens were visually reviewed. The full multi-feature screenshot gallery was not exhaustively reviewed. Native runtime and real-stack gates remain open for the environment reasons above.

## QA reports

- Flutter component/native report: `.out/local-features/20261024-213054/index.html` (`BLOCKED` only at Android/iOS runtime stages).
- Web report: `.out/local-features/20261024-212416/index.html` (browser checks pass; real-stack stages fail before service startup).
