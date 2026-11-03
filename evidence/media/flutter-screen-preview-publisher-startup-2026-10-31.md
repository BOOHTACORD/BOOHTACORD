# Flutter screen-preview publisher startup reliability — 2026-10-31

Task: FV2-060 / Flutter voice participant cards show inline screen previews; related server preview contract: T-079.
Source base: `27102e677b3e975dfea97970071836f4b493e2da`.
Status: implementation and source checks PASS; Android/macOS publisher-to-viewer media acceptance NOT_RUN.

## Change

Flutter uses one `ScreenPreviewClient` for Android and macOS. Its server-managed Egress `begin` request had a three-second timeout, shorter than the server's sequential LiveKit RoomService/Egress setup budget. A timeout could therefore leave the sender with its local immediate preview while the server never completed generation setup. When `begin` returned a transient error such as a publication-not-ready 404, the uploader previously waited for its next 30-second lease refresh before trying again.

The Flutter client now allows up to 30 seconds for `begin`, while retaining the three-second timeout for preview reads and invalidation. Failed setup retries with bounded backoff (1, 2, 4, 8, 16, then 30 seconds); changing leases or stopping sharing cancels the pending retry.

## Checks

- Regression-first: the delayed four-second `begin` response test failed under the old three-second timeout, then passed with the new deadline.
- Regression-first: the transient-404 retry test timed out under the old 30-second-only retry cadence, then passed with the one-second retry. The stop-cancels-retry test also passed.
- Focused Flutter tests: `flutter test test/screen_preview_client_test.dart test/screen_preview_sender_stop_test.dart` — PASS (8 tests).
- Full local feature run from `github/master`: Web unit/build/accessibility and selected Web scenarios PASS; Flutter unit PASS (1,736 tests); Flutter component captures PASS. Selected generated participant-card and screen-viewer captures were inspected at source resolution.
- Android debug APK build and install on `emulator-5554`: PASS; `ru.boohtacord.app/.MainActivity` opened and displayed the login screen. This is startup/build evidence, not media acceptance.
- macOS debug build: PASS (`BOOHTACORD.app`).
- Local real-stack Web and Android runtime stages: FAIL before the client scenario because disposable service `http://127.0.0.1:4812/ready` did not become ready. Restarting the Colima profile and retrying Android runtime reproduced the same service-readiness failure. The full run is recorded in `.out/local-features/20261031-221635/report.json` and its logs.
- iOS runtime: BLOCKED in that run.

## Acceptance still open

Android and macOS publisher-to-Web viewer delivery, including a decoded server-generated thumbnail and refresh, is NOT_RUN. The available AVD launch and widget captures do not exercise screen capture, LiveKit publication, Egress startup or a paired viewer. The Web real-stack scenario could not start because its disposable backend was not ready. No production media behavior or capacity claim is made.
