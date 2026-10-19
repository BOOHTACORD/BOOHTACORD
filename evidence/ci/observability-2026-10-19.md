# #402 — source-bound CI triage implementation

Date: 2026-10-19. Baseline: c569477fc0d125f3313e73742c34a2ea6aa5e454.
Parent: #382. The owner requested implementation first and deferred long actual
runs; this change analyzes existing metadata and runs focused fault tests only.

Implemented always-run sanitized job summaries/30-day evidence on ci-required,
server-quality and native-required, with source/run/attempt, selected components,
failed step/job URL, owner, reproduction command, timing and retry count. PR API
head and verified tested merge identity are explicitly distinguished. Cancelled
PR/dependency observations are not labelled master defects. Read-only manual
triage handles waiting runs; private names/logs/payloads are not published.

Metadata transport has at most two GET attempts only on known transient HTTP
500/502/503/504/timeouts/reset; auth, missing evidence, malformed JSON and
assertions do not retry. No test, signing, auth/ACL, health or runtime assertion is
retried or ignored. Existing required validation remains authoritative; failed,
missing or soft/conditionally hidden diagnostic evidence stays red. Actions API
access is read-only, with no production/signing/SSH credentials.

## Historical analysis — PASS (metadata scope only)

Replayed **40 original complete** sanitized #383 runs, each matched to its frozen
sample identity and recorded input SHA256. No new acceptance/release or API/log
collection was needed. Frozen analysis: `ci-triage-2026-10-19.json`.

- 15 PR CI + 15 former master CI + 3 server builds + 3 deploys + 2 Android releases
  + 2 Windows releases. No macOS release sample was available.
- 5 failures, 6 cancellations. Two recurring Windows GUI/SFU failures; two
  recurring Android signing/build failures; one Windows analysis/test failure.
- Root causes remain UNVERIFIED. Confirmed flake rate is null, not zero. Windows
  release rerun rate is 1/2; other sampled cohorts have no observed rerun.
- Workflow wall p50/p95, first-start delay, platform outcomes, runner execution
  minutes and every source URL are retained. They are before-migration
  observations, not a claimed speedup or exact required-green/master-healthy time.

## Focused validation — PASS

37 focused Python cases passed in the final run (1.829s), including wrong SHA/PR
merge parent, failed/missing/cancelled evidence, exhausted transient retry,
assertion/auth non-retry, runner wait, red-gate retention, metadata-unavailability
privacy and existing aggregate graph contracts.
Actionlint, 33-workflow/2-local-action trust inventory, delivery and SDK/input
policy checks passed. Spec traceability: PASS_INDEX_ONLY, 39 requirements; the
approved Windows brief remains unavailable on this host.

## Remaining evidence — NOT_RUN

New live summary integration, after-migration performance/flake sampling and owner
required-status readback are not established by local fixtures. #402 remains open
for that combined acceptance; the analysis never suppresses a red required gate
or substitutes metadata for physical/media/server rollout evidence. No external
notifications or automatic mutating remediation were sent.
