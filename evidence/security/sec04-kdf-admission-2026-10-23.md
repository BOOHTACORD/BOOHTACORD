# SEC-004 / GitHub #532 — bounded Argon2 admission

Date: 2026-10-23. Baseline: `0d6712eff067a570b41911f6d10a3b647606f064`.
Implementation: `70fd162def412a3b7e22be4630675213f9f5f8ba`.
Environment: macOS Apple Silicon / Apple M4 Pro, Go 1.26.4,
Flutter 3.47.6 / Dart 3.13.5; repository dependencies, including the supported
Go `golang.org/x/crypto` implementation. No libargon2 adapter or SDK replacement.

## Policy and boundaries

One shared process-local gate: **4 active, 0 waiting, 0 queue wait**. Existing
Argon2 parameters and actual active limit are preserved. A new request at
capacity gets typed `ErrBusy`; it does not wait holding a password in a KDF
queue. Cancellation is checked before admission, after reservation immediately
before KDF and after actual synchronous completion. An active permit is never
released while detached computation continues; no detached KDF is created.

All Hash/Verify/VerifyUnknown APIs now require context. Call sites:
login_user, register_user, change_own_password, complete_password_reset,
bootstrap_administrator, recover_administrator,
recover_last_administrator_access. Startup dummy explicitly uses Background
before serving requests. There is no non-context compatibility wrapper.

The four HTTP mutation paths return 503 `AUTH_BUSY`, Retry-After 1 and no-store
without cookie or mutation on capacity refusal. Existing IP limits, Origin,
body limit, secure cookie and ACL wrappers remain. Web and shared Flutter
retain the form/session, present the bounded retry delay, and only retry on a
new user action. Temporary passwords are not persisted. Account-budget order
(#533) and reset preflight (#535) remain separate work. This is not a global
deployment quota, production load profile, physical media or release gate.

## RED → GREEN

- Baseline `TestCancelledResetDoesNotDeriveOrMutate`: an already cancelled
  synthetic reset executed **1 real KDF and 1 Consume call** before returning
  context.Canceled. After implementation: **0 KDF / 0 mutation calls**, same
  cancellation result.
- Web regression initially ignored Retry-After on AUTH_BUSY. Flutter had four
  failing cases (login/register/reset/change), including reset losing the
  AUTH_BUSY code. New cases now pass with the same explicit manual retry delay,
  exactly one request, no unauthorized callback and preserved synthetic cookie.
- Barrier tests retain all four permits after in-flight cancellation, reject a
  fifth request, then execute real Go Argon2 and release every permit exactly
  once. Peak real-work wrapper concurrency: 4. No millisecond timing equality
  assertion or scheduler sleep is used as the security proof.
- Deterministic cancellation after permit reservation performs zero KDF and
  leaks no slot. Expired context, corrupt hash and entropy error leave capacity
  usable. A double lease release does not consume another operation's permit.
- Real service/handler tests cover known, unknown and blocked login,
  registration, reset and password change under saturation: identical safe 503,
  Retry-After, zero KDF, no cookie/session/mutation. Stores here are synthetic
  in-memory spies; this is not proof of PostgreSQL transaction or SFU removal.

## Executed verification

| Check | Result |
| --- | --- |
| `GOTOOLCHAIN=go1.26.4 go -C backend test -race ./internal/identity/... ./internal/security/rate_limit/... -count=1` | PASS |
| API composition compile: `go -C backend test ./internal/app/runtime -run '^$' -count=1` with the same toolchain | PASS |
| Focused Web auth/reset/profile/retry suites (18 tests) | PASS |
| Focused shared Flutter auth transport/form suites (18 tests) | PASS |
| Contract verifier: 19 tests, OpenAPI lint and 117 public operations / 4 private exclusions | PASS |
| Spec traceability: 39 approved IDs using the committed index; Windows brief unavailable | PASS |
| Signal catalog: 9 tests, seven aggregate KDF families added, existing producer fingerprints refreshed | PASS |
| Client parity policy, including `--base 0d6712eff067a570b41911f6d10a3b647606f064` and its two policy tests | PASS |
| Full Web unit suite (1623 tests / 487 files) and production build | PASS |
| Local QA Web browser profiles, including forced capacity on mobile/desktop login/reset | PASS |
| Real Go/PostgreSQL/Web critical lifecycle at widths 1440 and 393 | PASS |
| Full Flutter suite (1606 passed / 1 skipped) and selected component captures | PASS |
| Android emulator native runtime against owned local API | PASS |
| iOS simulator native runtime against owned local API | PASS |

Local identity race suites were run without a disposable PostgreSQL DSN; their
database-dependent cases skipped. Real-stack browser/native smoke is recorded
separately and does not prove the new saturation path against PostgreSQL.
The issue changes no SQL or transaction and does not require SQL ACL acceptance.

The first PR CI attempt required fresh parity review decisions relative to the
base for auth and telemetry (the latter owns the common Flutter HTTP transport).
Both decisions now cite the completed source-bound Web/Android/iOS regressions.
The base-aware verifier passed locally; only registry/evidence metadata changed
after local runtime acceptance, with no implementation or screenshot baseline change.

Local run: `.out/local-features/20261023-161039/`. Forced-capacity browser
responses are controlled HTTP fixtures; native smoke uses a real local API.
All 18 automated stages passed on the implementation commit with an empty
tracked diff. Command: `./tools/qa/local_features/check.sh --feature auth
--feature connection_status --feature screen --feature support --feature telemetry
--feature voice --base 0d6712eff067a570b41911f6d10a3b647606f064 --real-stack`.
The task-local environment selected the QA Docker context/config and bypassed
the host HTTP proxy only for localhost/127.0.0.1/::1/10.0.2.2. No global network
settings changed. The first attempted selection stopped before tests because
the modified contract also selected support; the complete selection above ran.
Do not infer forced-capacity native runtime, physical devices or media QoE from
component captures or normal native authentication.

## Measurements and visual review

Two sequential Go Hash benchmark samples on this Mac: about 14.35 ms/op and
16.47 ms/op. Retained benchmark: 16,471,251 ns/op, 19,927,437 B/op, 35 allocs/op.
The retained command was `GOTOOLCHAIN=go1.26.4 go -C backend test
./internal/identity/password -run '^$' -bench BenchmarkSupportedKDF
-benchtime=2s -count=1 -benchmem`. The sample supports keeping the existing
four active slots with no speculative waiting queue. It is not a production SLO
or RSS measurement. Four configured Argon2 work areas total 76 MiB before other
process memory and overhead.

Reviewed original-resolution Web capacity screenshots at 390×844 and
1440×900: login/reset busy message and primary action visible, credentials
masked, fields retained and editable; no message clipping. The existing mobile
login footer is close to the card edge; no CSS redesign or baseline approval
is included. Reviewed the shared Flutter busy-form capture (390×844): delay
fully visible, password masked, login action and reset link accessible.
Reviewed native Android/iOS auth and authenticated workspace captures at source
resolution: controls and server address fit, successful login reaches the
workspace and public support notice remains readable. Native signed-out PNGs
are identical to their full-sized initial auth PNGs (1080×2400 Android,
1206×2622 iOS), confirming the same cleared form after logout.

Scoped observations are saved in the run's `sec04-visual-review.json`. The
aggregate gallery remains REVIEW_REQUIRED because this is a review of relevant
auth/workspace images, not approval of every unrelated gallery image or a new
screenshot baseline. No unrelated UX/media gate is closed by this evidence.

## Local retained logs

Logs are under `.out/security-sec04/`, excluded from release artifacts.

| File | SHA-256 |
| --- | --- |
| red.log | 3eec006382f2f5cd6af2c618516e1a9b4535f20aec49cd505f4daa105e72efa1 |
| web-red.log | d2c1a6272863ddc29a851960edc0da76ba933b8c7d06c93a008cd61d45732528 |
| flutter-red.log | 5a9e32f654c8b9bcf229bad84e8cba68ef61d042a1da9291cd56e2be90122d79 |
| race-final.log | 616f5efb91a05bdcc242a7f6ae018418780f41e86a8ad548ade9985e3c3ba8dc |
| benchmark.log | 93abf26c4f12730bdc206cccdeebed461dcdb823b8fc3cf95655c4abc833a1d1 |

NOT_RUN: production deployment/load, physical Android/iPhone, macOS/Windows
installed-client runtime and physical media revocation. No claim of remote
timing indistinguishability, guaranteed availability under distributed load or
deployment-wide KDF coordination.
