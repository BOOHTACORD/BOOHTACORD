# Verified native-only promotion readback

Packet: bounded CI incident fix; backlog CICD-14, preserving CICD-11/13/12/03.
Route: windows_promotion/noop_readback. Composition edges are the existing
delivery routing command, its workflow artifact upload and readback entrypoint.

Existing behavior: a successful native-only route skips installation and has
no delivery receipt. The catalog observer unconditionally requires that receipt
and fails before source/catalog checks (retained issue610 evidence). Real
delivery provenance, source/attempt, install and acknowledgement stay mandatory.

1. Add a counterexample through actual readback.main with bounded fake GitHub
   metadata and real ZIP/hash/ownership fixtures. Baseline must fail its NOT_RUN
   outcome assertion, with no setup or external network failure.
2. Retain a source/controller/producer run-and-attempt route record from the
   existing verified routing decision; publish it without production secrets.
3. Accept a no-op only for successful route/skipped install, exact trusted
   producer jobs, and a verified source-bound master quality artifact explicitly
   declaring server_release_impact=false. Return NOT_RUN without catalog reads.
4. Reject foreign/tampered/missing/stale proof and impact=true. Preserve the
   entire existing real deployment receipt and acknowledgement path.
5. Run focused boundary/archive tests and nearest routing/deployment/promotion
   suites. Retain RED/GREEN and source hashes; use a separate PR/full CI.
6. Observe the existing workflow after merge on a qualifying native-only source
   before closing610; keep physical249/579 and urgent582 acceptance separate.

Target100/hard120 lines per source/test file; one no-op trigger family per leaf,
target8/hard16 production/direct-test files. No source, signing, ACL, server
runtime, release identity or mandatory gate weakening.582 candidate has priority.
