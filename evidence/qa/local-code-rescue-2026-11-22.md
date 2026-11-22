# Residual local-code integration — 2026-11-22

Base: `4a45e851ddb6e5203c293d46a0e674ffc9a73167` (`master`).
Candidate: `codex/local-rescue-fixes`; exact source is the containing commit.
Scope: update identity, administrative save/copy lifecycle, session first-check
schedule, optional isolated API harness. No production deployment or release.

## Behavior and preservation

- Identical update release IDs with contradictory order, known version or known
  declared build now yield `identity_conflict` in both Web and Flutter.
  Shared fixtures failed three cases before the fix and pass afterwards.
  Installed Android split-build normalization and required-update policy remain.
- Pending permission confirmation cannot save after disposal, reload or a changed
  draft. Three real widget scenarios failed before the fix and pass afterwards;
  every invalidated operation makes zero API saves. Existing member-only editing,
  conflict/reload handling and server-side authorization remain authoritative.
- A failed reset-link copy clears earlier success; successful retry clears the
  earlier error. The success/failure/success widget regression failed before the
  fix and passes afterwards. Clipboard failure is simulated at the platform
  boundary; this is not an installed-client clipboard failure reproduction.
- Session revalidation first checks are deterministically spread within the
  existing interval. Unknown digests preserve the full first interval. Existing
  cancellation, deadline, authenticated identity and close behavior remain.
- The restored API harness rejects all HTTP redirects and uses the current
  `/search/messages` route. Tests verify GET/POST across 301/302/303/307/308 never
  reach a second owned origin, plus successful direct requests and query encoding.
  No production traffic or capacity experiment was performed.
- Current Unicode guild-name validation, managed session-pool shutdown and
  screen-dialog accessible headings were retained and tested. The obsolete
  byte-count validator, disposable pool, broken standalone Dart tests, old
  catalogs/providers and monolithic administrative rewrite were not imported.

## Executed checks

All commands below run against the candidate working source unless noted.

| Check | Result |
| --- | --- |
| `npm test --prefix clients/web -- --run` | PASS: 601 files, 2083 tests |
| Focused Web evaluator, required update and screen setup suites | PASS: 27 tests |
| `flutter test` (pinned Flutter 3.47.7, Windows) | PASS: 2052 passed, 3 skipped |
| Focused Flutter evaluator/admin/role suites | PASS: 140 passed, 2 macOS-only skips |
| `flutter analyze --no-fatal-infos` | PASS: no errors/warnings; pre-existing info diagnostics |
| `go test -count=1 ./internal/realtime/connect_session ./internal/guild/update_settings ./internal/database/pool` | PASS on Go 1.26.4; local DB-dependent tests are not a full database gate |
| `python -m unittest discover -s tools/qa/backend_load -t .` | PASS: 6 tests, including 10 redirect subcases |
| `python -m tools.ci.native.contracts` (isolated WSL Linux clone) | PASS: Python 1847 tests, 27 known skips; contract/schema/action/SBOM checks pass |
| `pwsh -NoProfile -File tools/verify/spec_traceability/verify-spec-traceability.ps1` | PASS: 39 requirements and actual approved brief SHA verified |
| `python -m tools.product_map generate --check` | PASS after catalog companions were generated |
| `python -m tools.product_map validate-parity` | PASS for implemented parity projection; not a claim of full-map validation |
| `python -m tools.observability.signal_catalog.build --check` | PASS, no regeneration |
| `python -m tools.verify.client_parity.run --base origin/master` | PASS |
| `git diff --check` | PASS |

Full Flutter skips are two macOS-only recovery cases and one opt-in real Tempo
export test. Python skips are macOS/opt-in Tempo environment gates. These are not
reported as executed native/macOS/Tempo acceptance.

Local logs and captures are transient `.out/local-rescue/` and
`.out/local-features/` outputs, excluded from the committed source. Linux checks
use the owned Docker CLI, Node 24.18.0 and prepared Python 3.12.15 environment;
the Windows and Linux source files are synchronized with normalized line endings.

## Acceptance limits

Canonical Web run selected admin/auth/chat/connection/idle/screen/update/voice:
27 of 30 stages passed, with 667 captures and stable source identity. Its optional
numeric screen baseline was BLOCKED without dedicated SFU tokens (19 surrounding
tests passed); this patch does not change screen encoding or claim its performance.
Both real-stack stages initially failed before API launch because the local Linux
Docker CLI lacked Buildx. After attaching the existing Buildx plugin in an owned
temporary Docker configuration, both widths were rerun without changing tests:

- `python -m tools.qa.client_lifecycle.run --critical --portable-proxy --width 1440 --output-root .out/local-rescue/web-real-stack`: PASS.
- Same command with `--width 393`: PASS.
- Both reports confirm persistence after API restart and removal of owned
  resources. Authentication, role settings, reset links, chat recovery, SFU failure
  and decoded synthetic screen frames were exercised on the owned deployment.
- Inspected original-resolution role/member panels and required-update captures
  at desktop/mobile widths: readable labels, visible controls, preserved draft
  behind the update gate, no new clipping in the reviewed changed-feature surfaces.
  This is a scoped visual review, not inspection of all 667 unrelated captures.

Android emulator `BOOHTACORD_QA_ISSUE689` / `emulator-5554`, pinned Flutter 3.47.7:

- `python -m tools.qa.local_features.native --platform android --device emulator-5554 --target integration_test/local_qa_test.dart --output .out/local-rescue/android-runtime`: PASS; actual API, no mocks, 14 captures.
- Same runner with `--target integration_test/update_required_test.dart --output .out/local-rescue/android-update`: PASS; actual synthetic catalog, preserved form,
  Android Back rejected, both before/after captures inspected at source resolution.
- Native admin labels/search/actions are readable. The update action stays visible
  before/after Back, with no bypass to the obscured form. Installer was not launched.
- Windows and Linux candidate source matched across all 22 non-document paths,
  with normalized line endings. Tool-generated desktop registrants are excluded.

Physical audio, screen throughput, load capacity, installed-client update,
macOS runtime and production behavior are outside this patch's acceptance scope.
Hosted PR gates remain required until exact-head CI succeeds; local unit results
do not replace backend database, Windows build or actual-acceptance jobs.

Post-commit ownership exposed two new unmapped runtime files. The catalog now
links session revalidation and both update evaluators to their existing features;
the Flutter controller's evaluator import is an explicit dependency. Existing
IDs, revision history and UNKNOWN platform states remain intact. Generated map
companions were rebuilt. Catalog tests (33), ownership tests (22), transition,
new-path ownership and generation checks pass. This follow-up changes metadata
only; the application source exercised above is unchanged.
