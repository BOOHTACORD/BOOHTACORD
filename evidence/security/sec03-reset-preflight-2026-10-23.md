# SEC-003 / GitHub #535 — reset capability preflight

Base: `2cf4164ea363d7a35c28c3ea4f332bf936e7a355` (current master, #550).
Scope: backend reset ordering and focused client contract regression; approved
requirements REQ-AUTH-03 / REQ-SECURITY-01, leaf SEC-003, dependencies T-012 / SEC-004.
Only synthetic fixtures and owned disposable PostgreSQL; no production requests.

## Test-first RED → GREEN

On the baseline, `TestInvalidResetPreflightDoesNotDeriveOrConsume` observed one
native Go x/crypto Argon2 execution, zero preflight checks and one Consume for
unknown/expired/used fixture outcomes. Required assertion 0 KDF / 1 read-only
check / 0 Consume failed for all three. Log: `.out/security-sec03/red-preflight.log`.
After implementation all pass with exactly those expected counts. No libargon2,
no cryptographic substitute or production entropy/parameter change.

Early-cancelled reset already avoided KDF due to #532; this task additionally
observes cancellation before preflight, after a successful read, and after Hash
returns but before Consume. The latter test uses a real context whose cancellation
becomes observable at that boundary, while Argon2 executes natively. No production
hook, detached job or second semaphore is introduced.

## Actual PostgreSQL acceptance

Owned PostgreSQL 17.6-alpine, existing migrations, isolated per-test schemas and
standard repository/service/Go Argon2; `go test -race`:

- Missing/expired/used/malformed tokens: 0 KDF, unchanged password, token use,
  sessions, leases, revocation outbox and audit.
- Successful read: no mutation. Valid reset: exactly one native Hash, compatible
  verifier, old password fails, sessions/lease revoked, one queued revocation and
  one audit; unrelated account session remains valid. Reuse: no additional KDF.
- An unknown token whose SQL read is blocked by an exclusive table lock respects
  an earlier 100 ms parent deadline and fails closed with 0 KDF / no mutation.
  Repository unit tests separately require its <=2 s default and preserve earlier
  deadlines, parameter binding and read-only predicates.
- With a service paused after preflight, a separate acquired DB connection updates
  the same token's expiry within a one-second deadline: no row lock spans the KDF
  boundary. Actual hashing then occurs once; final Consume rejects the now-expired
  token without changing access/password/outbox/audit.
- Two service calls both complete valid preflight before release: 2 native Hash
  operations, exactly 1 successful Consume and 1 generic rejection. Only the
  winner's replacement verifies; one audit/outbox entry.
- A trigger rejecting the final reset audit raises a real SQL error: token use,
  password, session/lease revocation and outbox all roll back. Removing the trigger
  permits the same still-unused token to complete once.

Existing atomic Consume SQL and migrations are unchanged. Outbox insertion is
verified; physical SFU participant removal remains a separate gate.

Logs: `.out/security-sec03/postgres-focused.log`, `reset-final-race.log`,
`identity-race-postgres.log`. Full identity/rate-limit race suite ran with the owned
PostgreSQL DSN configured, not as a SQL-skipped local run.

## Client contract and scope

No HTTP schema, error code, client production source or UI change is needed.
Existing generic 400, safe 500, AUTH_BUSY/Retry-After and success semantics remain.
Focused shared Flutter tests cover unknown/expired/used/DB failure, one request,
no automatic retry/logout, existing cookie retained and no raw error reflection.
Web browser tests cover generic invalid-link and success states on desktop/mobile;
existing capacity and form scenarios remain required. Native forced-error UI and
physical-device acceptance are not implied by transport/widget fixtures.

PASS: full identity/rate-limit `go test -race` with owned PostgreSQL configured;
final reset/password suites rerun after the unknown-token deadline fixture change.
Focused Flutter (9 tests) plus analyzer and desktop/mobile Web reset profile
(8 browser tests) passed. Composition compiles. Contracts passed (19 tests,
117 public operations / 4 private exclusions); traceability references 39 IDs
using the committed index (original Windows brief unavailable). Base-aware client
parity/local-policy/catalog tests passed; source signal catalog remains 277.

Full local feature/native acceptance, screenshot review and exact-head GitHub CI
are pending at this source checkpoint. Results will be updated before completion. No capacity or production publication
claim; ambiguous final commit/response errors can still mean a reset committed.
