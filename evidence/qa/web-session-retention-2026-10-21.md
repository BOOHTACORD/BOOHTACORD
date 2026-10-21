# Web session retention — 2026-10-21

**Status:** `BLOCKED` for real-stack API/PostgreSQL acceptance; focused source and browser checks pass.

## Checks

- Targeted Go tests for session, login, authentication middleware, own-session listing, logout and session revocation: `PASS`.
- Browser regression `clients/web/tests/auth_session_retention/session_retention.browser.spec.ts`: `PASS`. The final focused rerun verified secure/HTTP-only/SameSite cookie attributes, a persistent expiry, authenticated restoration after reload, and restoration in a newly created browser context from persisted browser state.
- Local feature run `./tools/qa/local_features/check.sh --feature auth --feature voice --feature screen --base origin/master --real-stack --platform web`: Web unit suite, production build, and every registered browser suite passed. That full run preceded the additional browser-context restart assertion; the focused test passed again after that addition.
- Real-stack scenarios at 1440px and 393px: `BLOCKED` before API startup. This host has no `docker buildx`; the legacy Docker builder rejects `RUN --mount` in `backend/Dockerfile`. `VOICE_PLATFORM_TEST_DATABASE_URL` is also not configured, so Go PostgreSQL integration tests skipped locally.
- Source-resolution screenshot inspected: the isolated fixture displayed “Сессия сохранена” after login. This is a protocol fixture, not a production UI visual acceptance.

Only synthetic test credentials and identifiers were used; none are retained in the evidence. No production accounts or data were accessed. The generated local-feature report is `.out/local-features/20261021-141647/report.json`.
