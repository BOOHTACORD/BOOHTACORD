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

## Full local acceptance and retry

Implementation source: `16e6a49a151bbc32c1c18a3a3479e1e0ca4c1768`, empty tracked
diff (SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`).
Metadata-only follow-up records outcomes; application code is unchanged.

Executed `./tools/qa/local_features/check.sh --feature auth --feature connection_status --feature screen --feature support --feature telemetry --feature voice --base 2cf4164ea363d7a35c28c3ea4f332bf936e7a355 --real-stack` with the existing QA environment/loopback NO_PROXY/Go 1.26.4.

Original report `.out/local-features/20261023-215925/report.json` remains **FAIL**:
17 stages PASS, `web-real-stack-393` failed on its 5-second burst-50 message
visibility predicate before reaching reset. No code/check/timeout was changed to
silence it. Other outcomes: Web 1623 tests / 487 files, production build and all
registered browser profiles PASS; real API lifecycle at 1440 PASS; Flutter 1617
passed / 1 existing skipped; component captures, actual Android emulator and iOS
simulator smoke with owned local API PASS.

After native stages ended, reran exactly the failed command on the same clean
source: `python -m tools.qa.client_lifecycle.run --critical --portable-proxy --width 393`.
**PASS**, exit 0, including actual reset completion/focus, used-token rejection,
reset-link acceptance and Tempo verification; owned resources removed. Logs/result:
`.out/security-sec03/mobile-rerun.log` / `mobile-rerun-result.json`. The first
report is retained as FAIL; the retry is separate evidence, not a rewritten pass.
The failure did not reproduce in this retry, which does not prove chat delivery
can never time out.

Original-resolution visual review: Web invalid/success reset states at 390x844
and 1440x900, Flutter reset form at 390x844, native Android auth/workspace at
1080x2400 and iOS auth/workspace at 1206x2622. Messages/CTAs fit, result screens
hide password inputs and no secret appears. Native logout returns byte-identical
cleared auth screens. Reviewed real-API invalid reset result capture is 1280x720
(the lifecycle main context is 393, its dedicated reset result context has its
own size); explicit responsive fixtures establish mobile/desktop result layout.
Notes/hashes: `.out/local-features/20261023-215925/sec03-visual-review.json` and
`.out/security-sec03/mobile-rerun-result.json`. No screenshot baseline was
approved; unrelated gallery images are not certified by this review.

Forced reset-error transport/widget/browser cases remain distinct from ordinary
native smoke. Physical devices, forced-reset native UI, production load/capacity,
external metric storage, physical SFU removal and publication remain NOT_RUN.
Exact-head GitHub CI is pending; its final run/status will be recorded in the PR.
Ambiguous final commit/response errors can still mean a reset committed.
