# Upload acceptance extension: actual global cap, ENOSPC and deployed deadlines

Source `072426d60b1c0b1f7e5f66722a0da5faa00b50d7`, current Windows PC and owned Docker resources.
This extends the [earlier upload evidence](../upload-timeout/README.md); it preserves that packet's original scope and results.
I240.C2/#134 remains **FAIL**. Positive quota/writer checks do not override failed deadlines.

| Protection | Executed command | Platform | Mandatory before | Observed result |
|---|---|---|---|---|
| A real writer error removes partial files, releases slots/reservations and permits retry | `python -X utf8 .out/qa-upload-extended/probe_enospc.py` | Same immutable API image; separate DB/API/tmpfs in local PostgreSQL17.6/Docker Linux | Writer-failure facet of #134/I240.C2 | [TEXT+DM cleanup and retry PASS](enospc-result.json) |
| Declared-body requests with zero transmitted body bytes terminate under idle policy | `python -X utf8 .out/qa-upload-extended/probe_empty_body.py` | Windows HTTP client → actual main QA Caddy/API/PostgreSQL | Empty-body deadline facet | [Both FAIL](empty-body-result.json) |
| The actual15-minute maximum interrupts a read independently of idle60s | `python -X utf8 .out/qa-upload-extended/probe_absolute.py` | Same main QA deployment; real900s API clock | Maximum-duration facet | [Both FAIL](absolute-result.json) |
| Global16 cap applies across accounts and releases capacity for another actor | `python -X utf8 .out/qa-upload-extended/probe_global.py` | Nine real owned accounts; same main QA API | Global admission facet | [429/release/201 PASS](global-result.json) |
| Existing writer tests execute without skips | `go test -json -count=1 ./internal/storage/write_upload` | Go1.26.4 windows/amd64 | Nearest native controls | [5 PASS,0 skipped](writer-unit-result.json) |

Run helpers from `C:/Users/egkur/.codex/worktrees/local-qa-stack/BOOHTACORD`; run Go from its backend directory.
The profile and private dependencies remain in that worktree. Retained helpers are non-executable source copies under runner-source.
[Summary](summary.json), [unchanged source fingerprints](source-files.json), [raw native stream](writer-unit.jsonl).

## Actual mid-write ENOSPC

The fixture creates its own temporary database in the local PostgreSQL17.6 instance, API container and tmpfs attachment volume.
Its API has the exact main QA image ID, private dummy SFU credentials and an unreachable local SFU endpoint; production is not used.
The volume is2179483648 bytes (2GiB+32000000); filler-container memory is capped at3GiB.
It does not fill the host disk or the persistent QA attachment volume. This bounded RAM-backed fault is not a capacity profile.

For both TEXT and DM, native admission first reserved25000000 bytes and the real writer wrote8192 bytes to a staging file.
The client then paused. A helper filled only this volume to zero free blocks while the native writer waited inside the next read.
Sending the rest of the file reached the actual write-error path:500 INTERNAL, active0/reserved0/staging0.
After removing the owned filler file, a fresh upload returned201 and again left no staging files/reservations/active slots.
Observed500 is retained; this is not a claim of friendly507 admission behaviour or every possible I/O/fsync error.
The owned API, database, helper containers and tmpfs were removed; fresh Docker/PostgreSQL readbacks confirmed absence.

The first controller attempt failed before creating resources (UnboundLocalError). A corrected attempt passed;
the final measured revision additionally recorded8192 bytes already written before disk-full injection.
Both earlier receipts and measured v2 probe source are retained. The canonical probe adds only a raw-string prefix to avoid
a Python escape warning; its shell argument is identical to measured v2. Native product code was unchanged.

## Empty body and actual maximum-duration FAIL

Both zero-byte-body requests reached the actual API: active uploads rose from the two concurrent absolute probes to three,
without an additional disk reservation or staging file. Neither got a timeout response after80s; disconnect restored the baseline.

The absolute probes used actual TEXT and DM uploads, sending progress every approximately20s of API-native time until881.215s.
At the end, the API clock's oldest inflight age was933.735s. Both operations had been active for at least931.949s.
The final idle gap was at most52.717s, below idle60s; thus the missing response also contradicts the900s maximum independently of idle expiry.
Neither request returned408; together they still held two slots,50000000 reserved bytes and two staging files.
The controller then disconnected them and verified active0/reserved0/staging0. Host and VM clocks are reported separately.
The observed result uses the real15-minute policy, not the earlier scaled Go regression.

## Global16 and source limits preserved

Six additional owned members were registered through the normal API. The real5-per15min registration limiter returned429;
the initializer obeyed each Retry-After and completed without restarting API or changing limits.
Eight actors each held two actual uploads: active16, reserved400000000, staging16.
A ninth actor with no active upload received429 UPLOAD_CONCURRENCY_LIMITED / Retry-After1.
The metrics and staging count stayed at16. After one disconnect, its retry succeeded201; all remaining clients then disconnected,
leaving active0/reserved0/staging0. This distinguishes the global guard from the per-account2 limit.
Six static QA members and one successful1024-byte unattached fixture remain in the persistent local QA profile for reproducibility.

The Android device was only checked for availability (authorized SM_A576B; no screen capture or setting changes).
There is no physical Android, audibility, screen, production, load-capacity or long-lived voice/realtime acceptance claim.
No source tests or implementation were removed, and the43 consolidation decisions remain untouched.
