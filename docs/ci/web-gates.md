# Web profiles and source-bound results (#388)

The Web gate uses five complete profiles in separate hosted Ubuntu jobs. The
browser matrix uses three independent VMs; ports, synthetic users, Docker and
`.out` directories belong to those disposable machines. Commands within a profile
remain serial. Do not run multiple profiles in the same local checkout at once.

| Profile | Required coverage |
| --- | --- |
| fast | Native DSP tests, Node fixture/import tests, dependency/UI matrix checks, Vitest, TypeScript/Vite build and social preview verification |
| browser-shell | Accessibility (both existing commands), responsive shell, controls, microcopy, chat rhythm, message social and navigation |
| browser-conversations | Search sessions/presentation/dates, DM starter, own sessions, delivery, guild lifecycle, mentions inbox and readonly archive |
| browser-voice | Screen profile/setup/track names, mini player, member roster/popover, settings, header, passwords and voice interface/shortcuts/disconnect notice |
| sfu-network | Audio quality, actual screen-profile SFU and audio browser, then every restricted-network profile |

The immutable [baseline](../../tools/ci/web_suites/baseline-v1.json) records all
38 original commands from `tools/ci/native/web.py` at `0ed1cd91`, plus its source
SHA256 and the two explicitly added browser checks. The
[plan](../../tools/ci/web_suites/plan-v1.json) maps all 40 operations exactly once.
`test:watch` is interactive; `test:audio` aliases `test:audio:browser`;
`test:restricted-networks` runs through the actual Python network harness.
These are explicit mappings, not silently skipped suites.

Adding/changing a package test script requires an explicit plan inventory review,
an assigned profile and focused coverage tests. The historical baseline stays
unchanged. Dropped/duplicated/unknown operations, redirected reference commands
and unclassified scripts fail validation. No product test/configuration is
removed to shorten the gate.

## Local commands

Use the existing approved SDKs and `tools/requirements-ci.txt` environment:

```sh
python -m tools.ci.native.web --profile fast
python -m tools.ci.native.web --profile browser-shell
python -m tools.ci.native.web --profile browser-conversations
python -m tools.ci.native.web --profile browser-voice
python -m tools.ci.native.web --profile sfu-network
python -m tools.ci.native.web
```

Each individual profile performs one unconditional `npm ci`, builds source-bound
DSP assets with the existing digest-pinned compiler, and installs locked
Playwright Chromium with OS dependencies if it needs a browser. The fast profile
does not download Chromium. The default command executes the same complete plan
serially with one shared dependency preparation, finishing with the canonical
build/social check after the network fixtures. A dirty local working tree is
allowed, but its report explicitly has no attested source revision and cannot be
used as CI evidence. CI requires a clean checkout and matching `GITHUB_SHA`.

There is no test-result cache or assertion retry. SFU setup retains the existing
owned context; it is closed before restricted-network setup. Go/npm/SDK cache
identity and immutable release rules remain unchanged.

## Fan-in and artifacts

`frontend` always observes `fast`, the whole `browser` matrix and `sfu`. It requires
successful job results and exactly five bounded, flat JSON files. Every file must
match its profile, source SHA, plan digest, run ID, run attempt and reusable caller
namespace, with its full ordered operation list and positive finite timing.
Missing/failed/cancelled/skipped/partial/foreign/duplicate evidence is failure.
A prior PASS receipt is replaced by FAIL before validation, so exceptions cannot
leave a stale success. Only complete validation emits the unchanged
`source_revision/gate/status` Web receipt. The trusted producer identities remain
`frontend / frontend` and `web / frontend`.

Profile artifacts include namespace, SHA, run ID, attempt and profile. Original
sanitized browser capture paths are grouped per profile; SFU/network reports are
retained separately. Mandatory profile/receipt files use `if-no-files-found:error`.
Optional visual capture handling retains its previous semantics. Retention stays
30 days pending the separate artifact-policy task #387. No auth/configuration,
database or private log directories are uploaded.

**Repeat the complete workflow when repeating an attempt.** A partial rerun must
not borrow reports from an older attempt. Unavailable evidence stays failure.

## Measurement status

Actual same-source legacy/profile shadow runs, critical path/runner-minutes and
before/after p50/p95 are required before accepting this optimization. A green
unit test does not establish browser/SFU execution, speed or flake rate. Current
acceptance status is in the [evidence record](../../evidence/ci/web-gates-2026-10-19.md).
Physical media/device acceptance and required repository settings remain their
own gates; #385's setting is managed by the owner.

## Same-source shadow comparison

The read-only `Web CI same-source shadow` workflow uses three declared samples
per arm. Each arm permits one sample at a time; the new arm still runs all five
profiles in parallel. Sampling is finite, failures are retained, and no failed
assertion is retried or discarded to obtain a green dataset.

Every sample checks the same workflow source SHA. The legacy arm reads the exact
Git object for the original driver at `0ed1cd91`, verifies its SHA256, and executes
it against the current product/test source and pinned SDKs. Its observer only
delegates the original commands and records their completion/order. The old
workflow's initial `npm ci`/browser setup and the driver's second `npm ci` both
remain in this control. The baseline is executable source, never a fabricated
timing or simulated browser result. CI source is checked after preparation and
checks. Generated DSP assets are ignored build outputs.

The comparison consumes exactly six current-run/attempt/namespace summaries and
reads the actual run/jobs API with `actions:read`. It checks the upstream repo,
source SHA, attempt, complete successful jobs, hosted Ubuntu labels, distinct
parallel runners, timestamps and report timings. The measured new critical path
spans the first profile's start through the final fan-in's completion, including
SDK setup/uploads/internal waits. Runner-minutes sum all six job durations. The
legacy interval includes its whole job. Initial created-to-start wait is reported
separately and may include intentional serial sampling; it is not called pure
runner queue time.

The analysis job uses only its reviewed Python interpreter. It enforces clean
source without requiring an unused Node SDK; all application execution profiles
and the legacy control retain the mandatory exact Node identity check.

Nearest-rank p50/p95 use n=3 per arm, with no universal SLO/flake-rate claim.
All samples must succeed; the measured new p50 and p95 must both be lower for a
`PASS`. A complete slower/equal dataset is retained as `NO_GAIN` and the workflow
fails. Runner cost is reported even when it increases; Web-only improvement does
not imply a faster whole PR when Windows is the critical path.

The workflow is manual. Before registration on the default branch, a controlled
QA snapshot may add only a temporary push trigger to this file. That trigger must
stay outside the PR, its tree difference must be verified, and the QA source must
stay distinct from any PR/master release receipt. Stable server receipt publishing
is disabled for every shadow caller. Repeat a complete workflow to collect a new
attempt; old-attempt samples cannot fill missing evidence.
