# CICD-09 / #393 implementation checkpoint

Status: **NOT_RUN for hosted PR/master, full retry, deployment and measured
before/after acceptance**. #393 remains open. The earlier foundation record is a
historical checkpoint; workflows now implement the selected one-producer design.

Base: actual master `74197bec5951e672bb2daae85ab7a234ffffe545`, including accepted
#388 and #390. Focused tests failed before each implementation boundary: artifact
selector, bounded metadata reader, route/attempt decoder, installer preflight,
master-quality command, workflow policy, explicit manual-master rejection and
the previously unbound backend load-smoke upload. Red-stage logs are development
evidence, not actual hosted failed-gate acceptance samples.

The complete local suite passes **761 tests in 41.369 seconds**. Actionlint passes.
The full PowerShell workflow policy accepts **30 workflows and one local action**,
including trust/pins, native signing queue, sole producer/writer and shared
selection. Full local tests preserve legacy bundle selection and negative
foreign-producer/no-output/no-canary-disclosure coverage. Transfer, signer,
manifest/smoke implementations and all 19 original negative fixture subprocesses
are unchanged; execution of the full Linux release-mode workflow on this candidate
is still pending. Traceability is PASS_INDEX_ONLY39, not approved-brief validation.

Actual pre-change master source74197 has successful CI39237356016 and
Build server39237355984; both repeated backend/Web/contracts for that source.
Deploy39238470664 is running at this checkpoint. Actual timestamps, exact producer
binding and matched post-change observations remain to be retained; no latency,
runner-cost or master-to-deploy improvement is claimed from static job counts.

Tests cover exact clean upstream master context, complete source/map/needs-bound
quality, stale PASS overwrite, full receipt dependency, independent native scope,
immutable execution names including smoke artifacts, old-format compatibility,
mandatory provenance, current attempt/source/ownership, missing/failed/cancelled/
foreign/duplicate/expired/future evidence, bounded stable pagination and a rerun
starting during preflight. Real full rerun, cancellation/concurrent master-push
acceptance and external owner settings are not inferred from these tests.

## Receipt completion review

Before merge, reviewing the existing builder exposed an additional #393 DoD gap:
it ignored extra receipt files and ordinary JSON decoding accepted duplicate keys.
Nine direct filesystem tests failed first (five failures/four errors). A focused
decoder now requires exactly the three direct, bounded regular JSON files,
exactly the unchanged three body fields, unique JSON keys and PASS for the full
requested source. It rejects missing/foreign/failed/extra/linked/oversized or
malformed evidence without echoing private canaries. The actual builder delegates
to this decoder before archives, image building, smoke checks or signing.

An additional workflow regression failed before replacing the wildcard receipt
merge with three exact current-execution artifact downloads. Unknown artifact
labels can no longer overwrite a known receipt during wildcard merging. The
original publisher paths and the action's immutable per-name ownership remain
required by policy. No manifest format, signature, smoke or install lock changes.

The final local suite now passes **771 tests in 44.651 seconds**, plus Actionlint,
full PowerShell workflow policy and indexed traceability. Earlier 761-test hosted
proofs are scoped to predecessor1aea, not relabeled as current-candidate evidence.
The updated exact source still requires fresh PR and full release-mode checks,
master/retry/deploy acceptance and after measurements. #393 remains open.
