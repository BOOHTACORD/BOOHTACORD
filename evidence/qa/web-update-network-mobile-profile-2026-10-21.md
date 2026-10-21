# Web update banner, topology error and mobile profile — 2026-10-21

**Status:** Web checks `PASS`; real-stack acceptance `BLOCKED` by the local Docker builder.

## Changes

- Map browser network failures from channel topology loading to the shared Russian retry message. Remove the unconditional login prompt, which was inaccurate for network errors.
- Place the mobile account profile above the connected voice dock so it remains visible in the open navigation drawer.
- Register the network error and mobile profile scenarios in `tools/qa/local_features/features.json`.

## Validation

- Focused unit tests for topology errors and connection status: `PASS` (9 tests).
- Focused mobile profile browser check: `PASS`; also verifies the voice dock remains inside the 320×640 viewport.
- Connection status browser suite: `PASS` (3 tests).
- Local feature check `./tools/qa/local_features/check.sh --feature auth --feature screen --feature shell --feature voice --feature connection_status --platform web --base origin/master --real-stack`: Web unit suite, production build, accessibility checks and all registered browser suites `PASS`.
- Real-stack checks at 1440px and 393px did not reach the application: the active `colima-boohtacord-qa` Docker context has no `buildx` command, and the legacy Docker builder rejects the backend Dockerfile's `RUN --mount`. Both stages remain `BLOCKED` pending repair of that builder.
- Reviewed the 320×640 browser capture at source resolution. The profile row is visible directly above the voice dock, and the connection warning wraps within the drawer. No screenshot baseline was approved.

The focused screenshot is `.out/responsive-shell-browser-results/responsive_shell.browser-t-79ab9--dock-with-an-update-banner/account-footer-with-update-banner-320x640.png`. The full local feature report is `.out/local-features/20261021-210630/index.html`.
