# Master quality producer (#393 / CICD-09)

Status: implemented locally. Hosted PR/master, full retry, deployment acceptance
and comparative measurements remain pending; #393 stays open.

`Build server` owns master server quality. General CI handles PR, merge-group and
non-master manual checks. A manual general-CI dispatch on master explicitly fails
and names the correct workflows. PR checks never authorize master receipts: each
master push checks its new exact source. `Native master quality` uses the same
selector and existing Flutter/Windows callees without repeating server contracts
or holding the server bundle.

This is option A from #393. Keeping server checks and their signer in the existing
producer avoids an additional cross-workflow receipt transfer, token scope and
trust boundary. A new cross-workflow producer would not remove the required
post-merge exact-source checks. Actual before/after latency, job occupancy and
master-to-install observations must still validate the selected design.

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

Hosted evidence must verify one relevant master producer, three current-source
PASS receipts, signed/smoked bundle, full attempt retry, current producer binding
at installation, concurrent/cancelled source rejection and before/after timing.
Unit tests and static policy do not prove these live outcomes or external #386
settings. No physical/native media or capacity claim follows from this change.
