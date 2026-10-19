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
