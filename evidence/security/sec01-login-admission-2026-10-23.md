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

## Full local acceptance (PASS automated stages)

Implementation source: `2d8968b11ca6a77f83304d05d6ad9bde5d8ade2c`, empty tracked diff (`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`). Metadata-only follow-up binds these outcomes; application implementation is unchanged.

Executed `./tools/qa/local_features/check.sh --feature auth --feature connection_status --feature screen --feature support --feature telemetry --feature voice --base 7624f8685d1b02c42b55c7efb84993d9d1fac298 --real-stack`, using the existing local QA Python environment, Docker configuration, Go 1.26.4 and loopback NO_PROXY for owned stacks.

Report: `.out/local-features/20261023-190740/index.html` / `report.json`.
All 18 automated stages PASS: Web 1623 tests / 487 files and production build,
registered browser profiles, real API/PostgreSQL lifecycle at widths 1440 and393,
Flutter 1613 passed / 1 existing skipped, component captures, actual native Android
emulator and iOS simulator smoke with the owned local API. QA-owned runtime stacks
were cleaned by the harness. No production endpoint was used by the native tests.

Visual review: original-resolution Web 429 mobile (390x844) and desktop (1440x900),
Flutter 429 (390x844), native Android auth/workspace (1080x2400), iOS auth/workspace
(1206x2622). Manual retry guidance fits; password remains masked/editable; CTA is
visible. Ordinary native login reaches workspace and logout returns the cleared
form. Both native signed-out PNGs are byte-identical to their reviewed initial
auth PNG (Android SHA-256 `a690ef5982c98c13f16ecbd6359830ddc6ef540957242dc96725e2046200befd`,
iOS `3fc378a8e04bf7f232fed359587557022928d9f2cbcf71ded7c4a50c8a4d18da`).
Web mobile registration footer remains at the card edge as in prior captures;
no CSS redesign or baseline approval was performed. Detailed hashes/observations:
`.out/local-features/20261023-190740/sec01-visual-review.json`.

Aggregate gallery stays REVIEW_REQUIRED for unrelated images; the relevant
scenarios were reviewed, and all automated stages passed. Forced-429 browser and
Flutter transport/widget fixtures are distinct from ordinary native real-API
smoke. Physical devices, forced-429 native runtime, production load, external
metric storage, deployment-wide budgets and release publication remain NOT_RUN.
Exact-head GitHub CI is pending; the PR records its final run and status.

## CI-discovered NAT fixture correction

First PR CI run `39986064681` on head `5b3af4a7fd48e11d9c52e134ec3e8919749f1e8e`
FAILED `backend / load` (and consequently backend fan-in). The actual disposable
`nat_auth` report observed 204x8 followed by 429 at attempt 9; its old driver
incorrectly expected ten successful checks in one account before the IP limit.
This is a real expected policy change, not an infrastructure failure or green CI.
Other gate results are superseded by final-head CI.

The NAT profile still requires ten admitted source requests and the eleventh
`429 RATE_LIMITED` with Retry-After. It now performs eight successful logins with
logout each time, then two generic `401 UNAUTHENTICATED` on fresh synthetic
unknown logins. The eleventh uses another fresh unknown login so an exhausted
account cannot mask a broken outer IP limit. No increased production limit,
skipped profile, allowed early-429, changed error accounting, new operation or
load capacity claim. All five original load profiles remain mandatory.

Test-first fixture now enforces both budgets and asserts 204x8 / 401x2 before
429x1, ten admitted source operations, zero unexpected errors. RED: old driver
fails on premature account-limit response. GREEN: native Go 1.26.4 Linux
`go test -race ./internal/load/exercise_actor ./internal/load/run_profile -count=1`
in the owned cached Go container, with no network and read-only source/module
mounts. Mac direct execution of this Linux-oriented load fixture could not bind
its distinct loopback source; it is not counted as a successful native Mac run.
Logs: `.out/security-sec01/red-nat-linux.log`, `green-nat-linux.log`.

This follow-up changes the load driver/fixture and documentation only. The
application behavior and client source used by the completed 18-stage local
acceptance remain exactly as recorded above. Final GitHub CI must rerun all
mandatory gates and the actual Linux five-profile load suite.
