# Web automatic voice handoff

Date: 2026-10-25
Source base: `c27f7e89779c4f3dca4b3cce73859cd1064ffcda`
Scope: Web client handoff after an explicit voice-channel join.

## Implementation

- After the user selects a target voice channel, an occupied same-account browser controller is asked to yield immediately.
- A server `ACTIVE_VOICE_LEASE` or `ORIGIN_MEDIA_BUSY` conflict triggers one retry with `transfer=true`; the requested listener or microphone mode is preserved.
- The confirmation dialog and its channel/account state were removed. The prejoin shows transfer progress and does not expose another join action. A failed retry ends in the existing error state; it does not loop.

## Automated evidence

- **PASS** 12 focused voice connection/ownership/lease tests, including automatic browser-owner yield, one server-lease retry, preserved listener mode and no retry loop.
- **PASS** Web unit suite: 490 files, 1,634 tests.
- **PASS** TypeScript/Vite production build.
- **PASS** Playwright automatic-handoff UI scenario and full registered Web voice-interface suite.
- **PASS** `python3 -m tools.verify.client_parity.run --base origin/master`.
- **PASS** `git diff --check`.
- **PASS** critical authenticated Web real-stack acceptance at 1440 px and 393 px, including API, PostgreSQL, LiveKit, voice prejoin/ACL and screen-share lifecycle. Both runs removed their owned resources.
- **PASS** visual review of `voice-transfer-progress.png` at 1440×900: transfer status is legible, with no confirmation dialog or join controls. The capture verifies presentation only.

## Remaining acceptance

- **NOT_RUN** paired real-browser/tab media handoff against two simultaneously active clients; ownership and server conflict/retry behavior are covered by focused tests, while the real-stack lifecycle validates the surrounding authenticated voice flow.
- **BLOCKED** Android and iOS runtime checks: no registered QA devices were available. The change is Web-only; Flutter unit and component-capture suites passed.
- No media-quality or capacity claim is made.
