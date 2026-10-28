# I287.C6 isolated archive lifecycle

**PASS_SCOPED: 43 actual HTTP controls plus one staged tiny-upload control.** No new product defect found. This accepts only the current-source isolated API/PostgreSQL/private-storage facet. Previous-deployed-schema upgrade, provenance-backed legacy compatibility and released-client UI remain NOT_RUN; the full I287.C6/QA287 gate is not closed.

Literal source: `#92: archive/restore keeps channel ID, topology/history/search/download and privacy; archived sends/edits/uploads/reactions/pins denied including held upload and idempotency replay. Upgrade from previous deployed schema, legacy archive compatibility and released-client UI.`

Route: backend/internal/channel/archive_readonly_text and restore_readonly_text, bound by backend/internal/app/archive_text_routes/routes.go. The normal and explicit archive read endpoints have different contracts. Active guild readers can read explicit readonly archive history/search/files; ordinary current-channel routes become unavailable. Admin role and current topology revision are required for archive/restore.

| Invariant | Actual result |
|---|---|
| Active topology/history/search/file and replay work |200, byte-identical tiny file, accepted client replay201 returns original message; reaction/pin204 |
| Archive authorization and revision guard | Member403; stale revision409; valid archive200 keeps same channel ID |
| Archive preserves readable data | Explicit archive list/history/search/file200 for member; exact body/file checks; anonymous401; normal history/search/file404 and global search excludes archive |
| Archived mutation denial | Fresh send and accepted-before-archive replay404; edit409; upload404; reaction PUT/DELETE404; admin pin PUT/DELETE404; admin message DELETE404 |
| Denied writes are inert | Message/attachment/reaction/pin row fingerprints unchanged; channel ID/category/position/name unchanged |
| Held upload crosses initial ACL then archive | One220-byte multipart request;208-byte prefix sent, real new staging file observed at0.578s; remaining12 bytes released only after archive200;404 and no staged/final orphan at1.656s; attachment metadata remains exactly1 |
| Restore recovers same resource | Same-ID restore200; active topology/history/search/file200, edit200/send201/reaction-delete204/pin-delete204 recover; archive listing excludes restored channel |

Platform: existing private local deployment boohtacord-local-qa, Windows HTTP producer through localhost:18088, PostgreSQL17.6, API/Web images declaring source072426d60b1c0b1f7e5f66722a0da5faa00b50d7. Exact image IDs, raw source/helper hashes and loopback/npipe guards were recorded before execution in before.json. This is actual HTTP/database/storage runtime, without CUA, browser or physical-client acceptance.

Commands executed:

1. `python -B -X utf8 .out/qa-agent-archive/preflight.py`
2. `python -B -X utf8 .out/qa-agent-archive/native.py`
3. `python -B -X utf8 .out/qa-agent-archive/run.py`

Mandatory when accepting the current-source isolated archive lifecycle facet of I287.C6. Source, callbacks and environment were preserved; no product implementation was edited.

Native supplement: eight actual service/handler/PostgreSQL tests PASS, zero test-level skips/failures; command exit0, disposable schemas removed and public tables unchanged. Go reports one package-level skip for restore_readonly_text/postgres because that package has no test files. The initial parser counted this as a test skip and asserted; original result/events remain unchanged. native-review.json explicitly distinguishes the event types. Tests were run once, not repeated to silence the diagnostic. Native current-schema blocked/inaccessible-archive fixtures do not prove an upgrade from a previous deployment.

Fixture cost: zero new users; three normal new sessions on existing controlled accounts, one own category/TEXT channel, two own messages after restore, one real tiny attached file. Temporary staging and final-file inventory were observed through short --rm/network-none/read-only-root/cap-drop filesystem tool containers using an already-local PostgreSQL image and the API's verified UID. Only the known local attachment volume was mounted; inventory was readonly and removal targeted the exact owned UUID file. The nine service containers were not restarted or reconfigured.

Cleanup PASS: all three own sessions were revoked with guest/protected401 readback and removed by exact new public-ID/account guards; own channel/category/messages/attachment/reaction/pin/read-cursor/file resources removed. All ten selected table count/hash fingerprints and the pre-existing file-path inventory match baseline. Nine service IDs/images/configurations/start times and zero restarts are preserved; health200. Previous scope/search/guard-teardown artifacts and all native inputs remain byte-identical.

Expected retained metadata: monotonic topology revision38→42, plus six owned audit rows for category/channel creation, two pin changes, archive and restore. These were reviewed privately and contain no message body, file payload, cookie or password. The revision was not reset and audit history was not erased. API logs and public artifacts matched zero actual passwords, cookie/token values, usernames, account/message/scope IDs or fixture content.

Controller history: initial distroless `find` attempt failed before tests/fixtures; exact unavailability was reobserved as127 and filesystem tools adapted. The native parser assertion above and a read-only postrun audit selector that initially omitted the category UUID are retained diagnostics, not product bugs. All actual runtime controls completed on the first fixture run and finally cleanup passed.

Evidence: summary.json, runtime-checks.json, held-start.json, held-result.json, archive-immutability.json, cleanup.json, native-result.json/native-review.json, privacy-review.json and integrity.json. Raw payloads/IDs/cookies/SQL/logs remain private. No previous-deployment upgrade, browser/native filter UI, physical device, screenshot, media or production claim is inferred.

Slavik Gym report: route=channel/archive_readonly_text->restore_readonly_text; packet=I287.C6-isolated-archive-lifecycle; tokens=estimated:11500; method=manual_estimate; driver=archive-mutation-and-held-upload-boundary; next_split=provenance-backed-upgrade-or-released-client-archive-UI.
