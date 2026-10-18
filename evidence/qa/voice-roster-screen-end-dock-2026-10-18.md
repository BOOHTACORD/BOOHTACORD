# Voice roster, screen stop and dock copy — 2026-10-18

**Result: Web validation PASS; native-device acceptance BLOCKED / NOT_RUN.** The empty voice roster is centered, a browser-ended local screen capture returns the sender controls to idle without stale diagnostics or the generic start failure, and the dock omits the voluntary-leave message. Server revocation notices remain available in the dock, and the voluntary-leave notice remains on prejoin.

## Regression coverage

- `voice_roster.css` centers the empty roster message; the voice-interface browser regression checks its rendered alignment at 390 px.
- `VoiceScreenSession` forwards the LiveKit ended event even if the active profile was not recorded yet. `createScreenControls` treats that event as normal completion, invalidates in-flight start/measurement responses, clears stale diagnostics and releases its listener when stopped or disposed.
- The voice-interface browser regression checks that voluntary-leave copy is absent from `VoiceDock` while a server kick notice remains present. Existing prejoin notice coverage still expects the voluntary-leave message.

## Verification

- Web unit suite: 474 files / 1,576 tests PASS.
- Web production build with `VITE_PUBLIC_ORIGIN=http://localhost`: PASS.
- Voice-interface browser suite: 29/29 PASS; voice disconnect notice suite: 2/2 PASS.
- Local feature run `.out/local-features/20261018-184117`: Web unit, build, selected browser suites, and authenticated real-stack journeys at 1440 px and 393 px PASS. Flutter unit tests: 1,483 PASS, 1 skipped; registered component captures: 18 PASS.
- Android and iOS runtime stages are BLOCKED because no approved device targets were available. The overall feature report is `BLOCKED`; its 653-image visual review remains `NOT_RUN`. Relevant Web screenshots were inspected at source resolution; scoped observations are in `.out/local-features/20261018-184117/visual-review.md`.
- The Chrome system picker’s native stop button was not manually exercised. The ended-event path and in-flight diagnostic race are covered by focused Web unit tests; the real-stack run verified ordinary screen sharing but does not establish system-picker acceptance.

No Flutter source, media transport, API contract or server authorization changed. No hardware/media quality claim is made.
