# Artifact policy (#387 / CICD-18)

Implementation PR #433 is merged as `fe482078a2fa4e4964b6758770980d4b1a0b2fa6`,
tree `21ac39661e16286855916fba29d8acf56b7eb873`. All 14 PR jobs succeeded;
830 local Python tests and workflow policies passed. The completed storage and
retained-proof acceptance is recorded in
`evidence/ci/artifact-policy-final-2026-10-19.json`. Earlier local records describe
development checkpoints. Issue closure follows review and merge of this final record.

## Classes and retention

| Artifact class | Days | Rule |
| --- | ---: | --- |
| Synthetic Web/Flutter captures | 7 | Ordinary `pull_request`, `refs/pull/`, upstream job successful at publication |
| Other synthetic captures and failure diagnostics | 30 | Master, tag, manual QA, merge queue, failed/cancelled/unknown status |
| Mandatory execution reports, receipts and quality summaries | 30 | Missing mandatory file is a failure |
| Signed release bundles and native packages | 30 | Existing install/provenance/signature checks remain mandatory |
| Actual native/physical acceptance evidence | 30 | No substitution with synthetic screenshot integrity |
| Existing backend load diagnostic | 14 | Unchanged by this policy |

Repository retention maximum was observed as 90 days in authenticated read-only
Settings. Actual artifact expiry is checked independently; the setting alone
does not prove an upload's retention. Classification is evaluated at publication,
not inferred from an archive name or a later aggregate verdict. GitHub job logs
remain separate from the bounded synthetic archive.

## Lossless package and identity

Within each profile archive, identical PNG/JSON payload bytes are stored once.
`artifact-manifest.json` retains
every original logical path, size and SHA256; `payload/` contains content-addressed
files. PNG images are neither recompressed nor edited. The public
`capture-publication.json` records the upstream status and capture counts without
raw errors. Storage `integrity: PASS` never overrides a failed QA result.

The downloaded current PR archives restore all 1080 original Web files and all
34 mandatory Flutter frames, plus four public diagnostics. Flutter's measured
Dart part matches each of the 34 frame hashes. The separate R14 navigation upload
was an exact byte duplicate inside the full Flutter set; its logical path remains
mandatory in the consolidated package. Original legacy shadow controls are kept
for measurement, including their historical duplicate upload.

Identity includes repository, tested checkout SHA, workflow run/attempt,
namespace, component, profile and platform. Windows artifact names now include
source/run/attempt; public release filenames, native formats and pinned historical
fixture names remain unchanged. A PR head can differ from the tested merge SHA:
current head `ace00a65`, checkout `c8a78974` and master `fe482078` have the same
independently verified tree, but keep their distinct identities in evidence.

## Publication and privacy boundary

Publication requires a clean exact-source Git checkout on an upstream hosted
Linux job and a fresh pre-test marker. Success requires the current mandatory
profile result; the Dart result must enumerate the exact 34 frame hashes.
Mandatory parts upload before the capture retention decision. Missing screenshots
on failed tests can produce a partial/empty diagnostic package, never a QA PASS.
Invalid or private-shaped data has no raw-upload fallback.

The reviewed Web boundary has 16 finite output roots. Their configs start fresh
Vite fixtures on loopback with strict ports and `reuseExistingServer: false`.
The zoom helper creates and removes an owned `mkdtemp` Chromium profile; it does
not reuse a personal profile. Fixtures use controlled data and routed test API
responses. Flutter captures widget render boundaries with fixed test state, not
the user's desktop. The Windows GUI test owns a disposable hosted API/PG/SFU
fixture; only fixed public result fields and eight PNGs leave its private temp
directory. The separately retained Windows recovery result does not claim an
N-to-N1 UI test.

Only bounded PNG/JSON files under these roots are considered. Hidden paths,
logs, traces, HTML reports, `.env`, private configuration and unrelated files are
excluded. JSON rejects non-finite/duplicate keys and known credential/JWT-shaped
values. These checks supplement the fixture/data-flow boundary; they are not a
universal pixel/PII classifier. Synthetic fixture text is not an export of actual
messages, DMs, credentials or attachment contents. Do not point these publishers
at real user profiles, production conversation exports or private QA roots.

## Download and restore

Download a ZIP through GitHub Actions, record its artifact ID, repository/run
ownership, API `size_in_bytes` and `digest`, and independently obtain the tested
checkout source and namespace/profile. A PR run's head SHA may differ from its
tested merge checkout. Never infer the expected identity from the downloaded
manifest itself. Verify and restore with public values:

```sh
python3 -m tools.ci.artifact_policy.inspect \
  --archive /absolute/path/captures.zip --sha256 API_ZIP_SHA256 --bytes API_ZIP_BYTES \
  --source-revision TESTED_CHECKOUT_SHA --run-id RUN_ID --run-attempt ATTEMPT \
  --namespace web --component web --profile browser-shell --platform linux \
  --output /absolute/new/package --restore /absolute/new/original-paths
```

The CLI does not execute HTML/scripts, overwrite existing directories or follow
linked parents. It verifies ZIP bytes, bounded members, exact identity and every
payload before restoring PNG/JSON files. It proves storage integrity, not a test
verdict, production release authority or universal pixel privacy. Network/API
ownership verification is the caller's separate prerequisite.

The current four capture ZIPs and four mandatory part ZIPs were actually downloaded
and checked against independent API ownership, size, digest and checkout identity.
Six wrong digest/size/source/run/attempt/namespace cases against an actual downloaded
ZIP were rejected without partial output. Eight Windows GUI images independently
match their published hashes. These are source-specific checks, not universal
visual approval or new physical-device acceptance.

## Retained release and actual acceptance

The existing successful signed installation proof is in
`evidence/ci/master-quality-final-2026-10-19.json`: producer 39245984933 attempt 1,
source `3dc9d592`, bundle artifact 12183093648, successful install job 118052394587.
Its artifact remains available until 2026-11-18; availability metadata does not
claim that the outer 73 MB ZIP was downloaded again. Canonical receipt/signature,
immutable source and compatibility validation still governs retained installation.

Previously accepted isolated real-stack compatible rollback/restore is documented
in `evidence/release/qa12-live-compatible-rollback-2026-10-18.json` and issue #60.
Final run 39131556884/artifact 12138059261 was downloaded again; ZIP size/SHA256,
three PASS reports and ten capture hashes were verified. Expiry remains 2026-11-17.
This proves retained availability of an existing acceptance path, not a fresh
rollback rehearsal on `fe482078` or permission to roll back production. New
same-SHA delivery, SSH/health and approved rollout/rollback acceptance belongs to
#395 and remains open.

## Measurements and limits

| Matched scenario | Artifacts before → after | ZIP bytes before → after | Active runner-minutes before → after |
| --- | --- | --- | --- |
| Ordinary PR | 20 → 19 | 265348817 → 262862889 | 75.083333 → 77.083333 |
| Master server producer | 16 → 16 | 117372024 → 115038376 | 36.750000 → 35.783333 |
| Master Native, equal native inputs | 10 → 9 | 221483302 → 221480032 | 45.383333 → 44.366667 |
| Manual CI from QA tag refs | 20 → 19 | 265371939 → 262857356 | 78.100000 → 75.583333 |
| Web QA, complete 3+3 controls | 34 → 34 | 131537316 → 124646420 | 125.633333 → 126.000000 |
| Flutter QA, complete 3+3 controls | 28 → 25 | 768080896 → 768061226 | 107.233333 → 108.450000 |

Every original logical path matches the downloaded before archives: 1114 files.
Between independent runs, 1032 original files are byte-identical and 82 differ;
each current restored file matches its own manifest. Causes of all rendering or
timing variance are not inferred. Four current capture packages remove 2808389
raw duplicate bytes. Whole-run ZIP differences also include native compression
and rendering variation; they cannot be attributed entirely to deduplication.
These observed scenario totals are not billed minutes or a general speedup/SLO.
The server total includes all 11 jobs and bundle production; #393's separate
validation-only 34.6-minute figure has a different denominator.
The four actual QA comparison ZIPs were downloaded; source/run ownership, all
sample job intervals and nearest-rank statistics were independently recomputed.

Master server run 39268498370 completed all 11 jobs and produced a signed/smoked
bundle with all three verified exact-source receipts. Master Native 39268498376
was canceled after independent PR #435 advanced master to `4fa947da`: Dart and
Android succeeded, Windows packaging was canceled, and native-required correctly
failed. Its actual published FAIL result retains 30 days and was downloaded.
That run is excluded from successful before/after measurements. Full native
checks on the same implementation tree passed in current PR and tag CI.
Later, Native master 39270703331 on independent master `4fa947da` completed all
six jobs successfully with nine artifacts. Its Flutter/API/SDK/Windows fixture
inputs equal the native baseline; the independent Web change does not alter
that native scenario. The actual native quality and GUI ZIPs were downloaded:
exact source/run, PASS result and all eight PNG hashes match. This separate
native comparison does not relabel the canceled run as PASS or combine server
`fe482078` and Native `4fa947da` into a single-source 26-to-25 result. No rerun or
unrelated settings change was made to manufacture a green sample.

The original frozen implementation/application inputs are bound to `fe482078`,
not to the later independent Web feature. All five original scenario pairs have
identical relevant application, pinned SDK and original test inputs; the later
Native master pair has its own additional input-equivalence record. Before Flutter QA used its
historical push trigger, after used manual dispatch; parsed jobs/steps/matrices
are identical apart from that trigger. The old Web QA source `76f7d7f7` has a
different client tree and is excluded from matched comparison.

QA tags use non-product `ci-artifact-policy-*` pre-releases with zero binaries;
the existing stable Latest was preserved. They exercise tag-ref CI and retention,
not native release-tag signing/publication. Initial pre-#393 inventories and
three canceled development heads remain historical observations. No net
development/QA cost-saving claim is made. Required-status owner configuration
(#385), external runner/native publisher acceptance (#386/#400) and new delivery
acceptance (#395) remain separate gates.
