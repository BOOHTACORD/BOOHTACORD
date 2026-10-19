# Master quality producer (#393 / CICD-09)

Status: CICD-09 producer acceptance PASS on master
`3dc9d5929d1afb5d6151d418bad7cf3f6a763358`, merged in PR431.
The complete source/run/job/receipt and timing record is
`evidence/ci/master-quality-final-2026-10-19.json`. Earlier evidence files are
historical development checkpoints.

`Build server` owns master server quality. General CI handles PR, merge-group and
non-master manual checks. A manual general-CI dispatch on master explicitly fails
and names the correct workflows. PR checks never authorize master receipts: each
master push checks its new exact source. `Native master quality` uses the same
selector and existing Flutter/Windows callees without repeating server contracts
or holding the server bundle.

This is option A from #393. Keeping server checks and their signer in the existing
producer avoids an additional cross-workflow receipt transfer, token scope and
trust boundary. A new cross-workflow producer would not remove the required
post-merge exact-source checks. Observed before/after results are recorded below.

Contracts run once on every successful master selection, always in full release
guard mode. Backend/Web run once when server release impact is true. The always
running `server-quality` job requires the reviewed map digest, successful selector
and contracts, and exactly the required successful or skipped heavy gates. The
builder waits for all three gates and server quality; it does not wait for native
quality. Non-release changes skip backend/Web/bundle while still checking contracts.
Unknown paths and unavailable diffs retain the shared selector's conservative
behavior. PR required-status administration remains owner-managed (#385).

The three-field receipt body (source/gate/status), dedicated production builder,
signing key, manifest, smoke-test, pinned SSH, forward-history check and shared
non-cancellable production install lock are unchanged. Receipts, server bundles
and all other server-producer uploads include source SHA, run ID and attempt in
their immutable names. Builder downloads three explicitly named artifacts from that execution, without
a wildcard merge. The builder accepts exactly three bounded regular JSON files,
the original three fields and no duplicate JSON keys or extra receipt files.
Full reruns produce new attempt artifacts; old attempts remain retained. A partial
failed-job rerun cannot substitute old successful receipts: use a full rerun.

The mandatory provenance entrypoint checks repository identity, producer workflow,
event, master branch, exact requested source and successful completion. It reads
all bounded job/artifact pages, distinguishes the new graph by its successful
`server-quality` job, requires one current-attempt bundle, verifies artifact
ownership/size/digest/expiry and rechecks the producer before emitting download
outputs. A producer that changes attempts during preflight fails. Installers use
the validated artifact name and producer run ID; they never search by SHA alone.

Existing successful legacy producers remain readable using their original
`server-<SHA>` bundle name and original strict route shape. Only the new graph
allows successful contracts with skipped heavy gates on a proven non-release
route. Mixed legacy routes, PR/fork sources, failed/cancelled/incomplete gates,
missing/duplicate/foreign/stale/expired bundles and future attempts are rejected.
Legacy artifacts without a GitHub ZIP digest still require the existing bundle
checksum and signed-manifest verification; new bundles require a valid ZIP digest.

PR431 had all14 current-head checks successful. Its tested checkout and actual
master merge have the exact same verified Git tree. Build39245984933 completed
all11 jobs successfully in attempts1 and2; every attempt2 job started afresh after
the root retry. Native39245985181 completed all6 jobs independently. General CI
did not repeat a master push. Four small receipt/quality ZIPs per build attempt
were downloaded and checked against API size/SHA256/ownership/source. All16 old
artifacts remain alongside16 new ones; the selector requires the current bundle.

Deploy39247297539/install118052394587 successfully installed the exact source from
build attempt1. Canonical host execution verified the signed bundle, compatibility
and running state before its final source-bound installation marker. The first
transfer attempt was cancelled at20minutes, and its recovery is included below.
The outer bundle ZIP digest is API metadata; its complete ZIP bytes were not
separately downloaded locally. Full hosted release-mode QA ran771 Python tests,
all19 original negative fixture processes and four actual read-only API preflight
cases. Concurrent/rerun races are controlled regressions; deliberately concurrent
production mutations were not used as a test fixture.

| Descriptive measurement (one observed source per side) | Before | After |
| --- | ---: | ---: |
| Server validation jobs, including new quality aggregate | 16 | 9 |
| Validation runner-minutes | 67.566666 | 34.6 |
| Producer-created to bundle, seconds | 564 | 646 |
| Producer-created to installed, seconds | 1646 | 2333 |

Occupancy excludes selectors, native jobs, bundle, deploy and development QA.
The after installation interval includes cancellation and recovery; it is not a
clean first-attempt latency sample. Bundle creation was82seconds slower in this
sample. Lower validation occupancy does not establish billing, p50/SLO or deploy
speedup. Per-job decomposition is retained in the final record.

The full retry proves new current-attempt production artifacts and receipt
selection. Repeated installation of its same-SHA bundle remains unaccepted under
#395, which explicitly owns same-SHA delivery, SSH/health failure, sequential
releases and compatible rollback evidence. Its first delivery also timed out
during SCP; the cancellation is not an immutable-manifest rejection. The canonical
retry was still running when this record was written. Host signature, immutable
manifest/history and install-lock guards remain unchanged. These outstanding
rollout/rollback/transport gates do not receive PASS from this producer record.
External #385/#386 settings, physical/native media and capacity remain separate.
