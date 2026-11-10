# Issue 689 bounded session revalidation under blocked writes

**Goal:** Detect revoked sessions independently of a slow socket writer and close within the issue's bounded revalidation window.

**Route:** `backend/internal/realtime/connect_session` session lifecycle; retain one application writer and existing authentication contract.

- [x] Reproduce delayed checks when a client stops reading and distinguish transient session-store outage from revocation.
- [x] Run an owned monitor independently of writer progress, compare the original account/session and bound close behavior.
- [x] Run existing PostgreSQL revocation tests, focused race tests and native checks. Full concurrent write/revoke and load acceptance remain separate.
