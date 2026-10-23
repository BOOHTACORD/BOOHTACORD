# SEC-001 / GitHub #533 — account admission before verifier

Base: `7624f8685d1b02c42b55c7efb84993d9d1fac298` (master, merge #548).
Host: macOS Apple Silicon. Only synthetic local fixtures and disposable PostgreSQL.
No production requests, user data or cryptographic stand-ins used.

## Initial regression (RED)

Before implementation, `TestAccountBudgetPrecedesEveryVerifierIncludingCorrectPassword`
failed: exhausted test budget still called the fake verifier 3 times and returned
204 / one session cookie rather than 429 / one verifier call / no cookie.

On native `golang.org/x/crypto/argon2` (not libargon2),
`TestAccountBudgetPreventsFurtherNativeKDFAndSessions` ran 12 wrong attempts and
one known correct candidate. Baseline: 13 KDF in each known/unknown/blocked case;
active account returned 204 and persisted one in-memory session, blocked account
403, unknown 429. Required regression: 8 KDF then 429, zero sessions/cookies.
Logs: `.out/security-sec01/red-handler.log`, `red-native-kdf.log`.

Flutter test-first RED: login/register 429 retained the session but did not
surface Retry-After/manual delay. Log: `.out/security-sec01/red-flutter.log`.

## Implemented boundary and focused results

Policy: 8 admitted attempts / fixed 30 seconds / normalized login / process,
including successes; denied requests cannot extend the deadline. Max 50,000
entries, no active-budget eviction, live reservations retained across expiry.
Ambiguous started cancellation/errors remain charged; only proven not-started
work refunds once. See `docs/runbooks/login-account-admission.md` for availability,
NAT/IP limits, saturation, restart/replica scope and finite private metrics.

PASS: native-KDF regression, atomic reservation/race tests, bounded storage and
expiry, success recovery, same-login case folding/multiple source addresses,
independent accounts behind NAT, original 11th-IP rejection, cancellation and
strict JSON/8 KiB boundaries. The shared four-slot KDF admission is unchanged.

PASS: `TestAccountAdmissionRejectsWithoutPostgresSessionAndRecovers` on owned
PostgreSQL 17.6-alpine, actual migrations and repository, with `go test -race`:
one admitted wrong lookup; four denied correct candidates cause zero additional
lookups and zero sessions; after advancing the admission clock 30 seconds the
actual verifier creates exactly one PostgreSQL session and secure cookie. No
schema or SQL behavior changes. Local PG uses a unique disposable schema, removed
by the fixture; no backup, volume snapshot or production database is involved.

PASS: focused Flutter authentication, capacity and auth-screen suites (25 tests).
429 handling is scoped to authentication and preserves ordinary transport session
and telemetry behavior. Web already handles 429; explicit mobile/desktop browser
regression added. New finite synthetic capture: `auth-rate-limit-mobile.png`.

## Verification commands and results at source checkpoint

PASS: `GOTOOLCHAIN=go1.26.4 go -C backend test -race ./internal/identity/... ./internal/security/rate_limit/... ./internal/config/runtime -count=1` with the owned disposable PostgreSQL DSN configured. All selected packages passed; SQL cases were actually run. `identity-race-postgres.log` retains package results.

PASS: focused Flutter tests (25), analyzer (no issues), Web password-generation browser profile (12 desktop/mobile scenarios). No automatic request occurs before another explicit action; fields stay masked/editable, no browser storage is populated, existing secure cookie is retained on 429.

PASS: `tools/verify/contracts/verify-contracts.ps1` (19 parity tests, OpenAPI 3.1 lint and 117 public operations / 4 private exclusions), `tools/verify/spec_traceability/verify-spec-traceability.ps1` (39 IDs, committed requirement index only; original Windows brief unavailable), base-aware `tools.verify.client_parity.run --base 7624f8685d1b02c42b55c7efb84993d9d1fac298`, and 21 catalog/capture inventory/parity/local-policy tests. Source signal catalog regenerated: 277 signals; its new private collectors are not claimed to be stored externally.

Full local features/native runtime, screenshot review and exact-head GitHub CI: NOT_RUN at this source checkpoint. This record will be updated with actual results before completion. No claim of physical devices, forced-429 native runtime, production load, deployment-wide budgets or release publication.
