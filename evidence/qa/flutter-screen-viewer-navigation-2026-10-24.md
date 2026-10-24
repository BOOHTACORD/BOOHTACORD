# Flutter stream viewing across navigation — 2026-10-24

**Source:** Web PR [#452](https://github.com/Egkurilov/BOOHTACORD/pull/452), issue #349. Flutter follow-up: PR #572.
**Base:** `4b8a48e6540207e4e0082ed735af8a0700d687a0` (`master`).

## Scope

When a user selects a remote stream and changes from its voice channel to text, a DM, or workspace settings while keeping the same voice connection, Flutter keeps the selected subscription mounted and shows the mini-player automatically. Returning to the voice channel hands the renderer back to the room. Leaving or changing the voice lease clears the selection. Stopping the mini-player ends viewing without leaving voice.

## Results

- Flutter full unit suite: **PASS** (1,636 passed, 1 skipped).
- Focused navigation regression, including text, DM, settings, return to voice, and ended-stream behavior: **PASS**.
- Flutter component captures: **PASS** (338 tests); the mini-player capture inventory matches all 150 registered files.
- CI artifact-policy tests: **PASS** (21 tests); client-parity validator and feature JSON validation: **PASS**.
- Dart analyzer on changed Flutter files: **PASS** (no issues found).
- Web unit, production build, accessibility, and registered browser suites: **PASS** in `.out/local-features/20261024-220405`.
- Web real-stack viewports: **FAIL before service startup**; the disposable API did not become ready because the local Colima Docker service was unavailable.
- Android/iOS runtime checks: **BLOCKED** because no QA device or simulator was configured.
- Live native stream acceptance: **NOT_RUN**. Synthetic fixtures prove layout and state transitions, not decoded media playback.

## Visual review

Inspected the captures at source resolution:

- `parity-pinned-workspace-1440x900-ime0-scale2.png` (1440 × 900): the selected viewer remains visible over the text channel; the composer and workspace header remain usable. The stream area shows a fixture waiting for a frame.
- `flutter-screen-viewer-mini-player-mobile-393x852.png` (393 × 852): the mini-player remains visible below the DM composer and above the voice dock, with its viewing controls present and no clipping. Its video also uses the waiting-frame fixture.

The captures do not establish real API/SFU connectivity or media playback.

## QA report

Local feature report: `.out/local-features/20261024-220405/index.html` (overall **FAIL** only at the unavailable real-stack service startup and **BLOCKED** native runtime stages).
