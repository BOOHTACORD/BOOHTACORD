# Web connection status panel — 2026-10-21

**Status:** `BLOCKED` for real-stack acceptance; Web unit, build and browser checks pass. The visual review of the focused browser capture passes.

## Scope

This presentation change belongs to T-022, voice controls and recovery. Chat, voice and roster remain independent states; the two retry buttons still emit their existing separate events. No server, ACL, contract or media behavior changed. Native runtime is not applicable to this Web-only component.

## Checks

- Focused browser scenario, `clients/web/tests/connection_status/status.browser.spec.ts`: `PASS` (3 tests). It covers independent statuses and retries, hidden all-connected state, keyboard focus, narrow-width wrapping and 200% text.
- Local feature run selected `connection_status`, `auth`, `screen`, `shell` and `voice` because the edited feature catalog is mapped to those existing features: Web unit suite and production build `PASS`; every registered selected browser suite `PASS`.
- Web real-stack at 1440px and 393px: `BLOCKED` before API startup. The configured `colima-boohtacord-qa` Docker context has no working `buildx` component; legacy `docker build` rejects the backend Dockerfile's `RUN --mount` instruction. Setting `DOCKER_BUILDKIT=1` confirmed that buildx is missing or broken. The stack did not reach application-level checks.
- Reviewed the focused 320×720 screenshot at source resolution: the recovery states sit in a rounded, inset dark card; status dots distinguish retrying chat, disconnected voice and unavailable roster; both retry controls have consistent contrast, spacing and alignment. The status and action labels stay inside the sidebar. The 200% text test also confirms no horizontal overflow. No screenshot baseline was approved.

The local feature report is `.out/local-features/20261021-170517/index.html`; the reviewed image is `.out/local-features/20261021-170517/images/web-connection_status/status.browser-recovery-pa-4e6a0-actions-in-a-narrow-sidebar/connection-status-recovery-320.png`. Real-stack remains open until the local QA Docker builder is repaired and the two viewport journeys are rerun.
