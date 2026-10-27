# #134 / I240.C2 — real stopped upload bodies do not time out

**FAIL**, source `072426d60b1c0b1f7e5f66722a0da5faa00b50d7`, current Windows PC and separate local QA stack.
Actual API uses PostgreSQL17.6 and the repository Caddy route. Production and the phone were untouched.

| Protection | Actual command | Platform | Mandatory before | Result |
|---|---|---|---|---|
| Stopped TEXT multipart body releases slot, disk reservation and staging file at native60s idle deadline | `python -X utf8 .out/qa-upload-faults/probe_idle.py` | Windows HTTP client → actual local Caddy/Go/PostgreSQL | Accepting #134/I240.C2 | [FAIL at80s](idle-text-result.json) |
| The same invariant for DM, using only the two synthetic participants | `python -X utf8 .out/qa-upload-faults/probe_dm_idle.py` | Same actual stack and owned DM | Accepting the DM upload path | [FAIL at80s](idle-dm-result.json) |
| Two active uploads reject the third; disconnect cleans resources; progressing TEXT/DM bodies remain valid | `python -X utf8 .out/qa-upload-faults/probe_controls.py` | Same actual stack | Accepting quota/timeout changes | [Scoped PASS](controls-result.json) |
| Real net/http HTTP1 request-body reads unblock under the wrapper deadline | Native Go overlay command in linked result | Go1.26.4 windows/amd64, real loopback server/socket | Accepting the timeout mechanism | [idle+absolute FAIL](native-network-result.json) |
| Existing unit controls still execute | `go test -json ./internal/storage/upload_request ./internal/storage/admit_upload` | Go1.26.4 windows/amd64 | Comparing the existing oracle with the real-network counterexample | [4 PASS,0 skipped](native-unit-result.json) |

Commands run from `C:/Users/egkur/.codex/worktrees/local-qa-stack/BOOHTACORD`, except Go commands run from its backend directory.
The helpers restrict authority to the owned local project and loopback origin and read credentials privately from the local staging profile.
Do not point them at production. [Actual source/runtime fingerprints](source-runtime.json), [summary](summary.json), [duplicate search](duplicate-search.json).

For each of TEXT and DM, a valid authenticated upload sent the multipart file header and8192 bytes, then deliberately stopped sending.
The original policy is60s idle /15min absolute. At80.14s/80.16s of host elapsed time, respectively, no response had arrived;
the real API still reported one inflight operation and25000000 reserved bytes, and its staging directory contained one file.
The API's oldest-inflight clock separately measured73.54s/73.58s, also beyond60s.
Only the controller's explicit client disconnect ended the operation. Afterward both metrics and staging-file count returned to zero.
These25000000 bytes are disk-budget reservations, not an equivalent RAM allocation.

Positive controls held two operations across TEXT/DM. A third completed request received429,
`UPLOAD_CONCURRENCY_LIMITED`, `Retry-After: 1`; it did not bypass the per-account cap.
After closing the held clients, two fresh uploads progressed at25s intervals and both returned201 after75s.
The final inflight/reservation/staging state is zero. Their two successful32768-byte synthetic unattached fixtures remain in local QA storage.

The existing fake blocking reader's Close explicitly wakes Read, and its unit test passes.
The added overlay instead opens an actual httptest HTTP1 server and a raw TCP client, sends one byte of a larger declared body,
then expects408. Both40ms idle and40ms absolute policies remain blocked beyond the500ms observation bound.
The overlay adds only a new test file; it does not replace production code. The Go invocation exits1 with both subtests failing;
each deployed stopped-body probe also exits1.
Raw [existing-unit JSON stream](native-unit.jsonl) and [real-network JSON stream](native-network.jsonl) are retained.

To recreate the overlay, map the absolute virtual filename
`backend/internal/storage/upload_request/native_network_test.go` to the retained [test source](runner-source/native_network_test.go.txt)
using a private Go overlay JSON `Replace` entry. Run the exact command in [native-network-result.json](native-network-result.json).

Root-cause evidence: upload_request.expire cancels context and calls source.Close while the handler remains blocked in source.Read.
The installed Go1.26.4 server body's Read and Close lock the same mutex; see [local source fingerprint](stdlib-rootcause.json)
and the upstream [Go HTTP1 server-body issue](https://github.com/golang/go/issues/78939).
The real-network regression confirms the mechanism independently of Caddy and PostgreSQL.
An implementation fix must interrupt the actual route-specific network read and preserve progress, cleanup, ACL and unrelated realtime/media policies.
Calling Body.Close alone is insufficient in the measured path; applying a global TimeoutHandler would violate #134's scope.

Global16 concurrency, actual writer/disk errors, a completely byte-less stalled body, the deployed15-minute absolute duration,
physical Android and long-lived voice/realtime acceptance remain separate NOT_RUN scenarios.
The scaled real-network absolute test is not a15-minute deployed runtime measurement.
No product code or tests were deleted/changed; the43 consolidation decisions remain untouched.
I240.C2 is FAIL because a required invariant is contradicted; the parent QA issue cannot close.
