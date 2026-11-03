# CI restricted-network observation regression

The first CICD-01 PR run failed the existing TCP transport assertion:
[run 39158751656, frontend job 117767385899](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/39158751656/job/117767385899).
It passed baseline UDP, then failed `matrix.browser.spec.ts` on the UDP-blocked
profile's expected selected TCP transport. That failed sample was not retained by
the old fixture, so its precise cause is unproven. No assertion was retried or bypassed.

Inspection found an evidence-acquisition timing hazard: the fixture polled only
receiver RTP, then read sender diagnostics once. It now samples both peers within
the same 15-second bounded connection attempt, requiring selected expected protocol,
directional RTP bytes on that same transport, and observed RTP growth from both.
The original final protocol/counter assertions remain. Sanitized observations are
retained on failure too; no credentials/raw candidates/addresses/SDP are retained.
No application UI, diagnostics implementation or network isolation rule changed.

Five readiness/privacy Node tests and eight namespace-isolation Python tests PASS.
Tests failed before the new helper implementation.

Actual repeatability proof: [run 39160333284](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/39160333284),
job `117772110509`, temporary [PR #412](https://github.com/BOOHTACORD/BOOHTACORD/pull/412)
(closed without merge). Three independent complete Chromium/LiveKit matrices
passed **15/15 profiles**, stopping on any failure, with zero test retries:

- baseline/recovery: selected UDP and actual directional RTP on both peers;
- UDP blocked: selected TCP and actual directional RTP on both peers;
- media blocked/signaling blocked: expected failed connectivity and no RTP.

Every positive profile required three observations before both peers met the
stronger readiness predicate. These passes demonstrate correct bounded acquisition
on the tested runner; they do not retrospectively prove the precise missing field
in the original unretained failing snapshot.

The ZIP digest and 14 fixture/diagnostics source hashes were verified against the
proof Git objects. [Receipt and three complete sanitized matrices](restricted-protocol-2026-10-18/receipt.json)
retain exact heads, job/artifact IDs and hashes. Active proof workflow and ordinary
CI trigger suppression exist only in the unmerged disposable branch. Physical
home/hotspot networks, audible quality, production revocation and capacity remain
NOT_RUN. This is a CI test-harness correction, not media capability acceptance.
