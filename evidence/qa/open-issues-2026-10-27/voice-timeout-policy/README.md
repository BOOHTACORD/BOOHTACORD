# I287.C9 isolated voice-timeout API policy

**PASS_SCOPED: 55 actual HTTP controls; native19 PASS, zero test/package skips or failures.** Cleanup PASS. No new product counterexample was found in the executed facet. Full I287.C9 remains PARTIAL: this is not actual SFU participant eviction, reuse of an already-issued JWT against LiveKit, native/Web dialog or physical acceptance.

Literal source: `#97: explicit authorized timeout set/change/lift, expires<=24h/reason allowlist, target/current-session changes, old credentials denied and eventual SFU revocation; pending truthful; TEXT/DM unaffected, no auto-unmute/rejoin; native dialog/Web separate.`

Selected route: backend/internal/voice/manage_voice_timeout, bound by backend/internal/app/media_routes/voice_timeout_routes.go. Contract/source preserve HTTP sessions and TEXT/DM while revoking logical voice leases. PUT202 is committed restriction/removal intent; its pending flag does not mean physical removal completed. DELETE200 does not restore old leases or cancel durable work. Acquire and credential-refresh refusals use409.

| Invariant | Actual local runtime result |
|---|---|
| Only authorized administrator can mutate; self/admin can read | Member PUT/DELETE403, peer read403, anonymous401, revoked own admin session401; controlled old/current target sessions read200 |
| Reason and database-clock expiry validation | DISRUPTION/HARASSMENT/SPAM/OTHER accepted202; past, beyond24h, invalid reason/date, missing expiry and unknown property400; future23h59m58s accepted |
| Existing voice lease is invalidated | First timeout202 reports revoked_leases1/pending=true; old lease has KICK/revoked; credential refresh409; target Acquire409/VOICE_TIMEOUT for both HTTP sessions and transfer false/true |
| Other account and nonvoice communication stay usable | Control account explicit Join201; both target HTTP sessions remain authenticated; own TEXT and DM before/during/after send201 and receiver read200 |
| Change/replay/lift obey policy | Three reason/expiry changes202 revoke no extra lease; duplicate set adds no audit; normal/idempotent lift200 removes expiry/reason and retains pending work; old lease remains revoked and credential refresh409 |
| Lift requires new explicit Join | No active target lease before the explicit new command; new Join201/new credential200; no backend resurrection of the old lease |

**Pending/dispatch limit:** the first restriction response and subsequent state/lift responses report pending=true. Real DB observations retain durable work before/after lift. During the bounded observation, every owned work row remains completed=false, attempt_count0 and unclaimed. No dispatch attempt or completion was observed. The three rows ultimately include timeout removal and the two explicit release intents. They were removed only during owned fixture teardown after their receipts were captured; runtime lift did not cancel them. No participant joined the SFU and neither issued JWT was used to connect. The native worker retry/stub tests are a separate supplement.

Platform: Windows HTTP producer against existing private localhost:18088 deployment boohtacord-local-qa, PostgreSQL17.6, API/Web immutable image IDs declaring source072426d60b1c0b1f7e5f66722a0da5faa00b50d7. Fresh health/loopback/npipe/image-label checks and source/helper hashes are recorded before runtime; source/helper bindings preceded native tests. No clock, role, configuration, source, container restart, production, CUA or browser action occurred.

Actual commands:

1. `python -B -X utf8 .out/qa-agent-timeout/preflight.py`
2. `python -B -X utf8 .out/qa-agent-timeout/native.py`
3. `python -B -X utf8 .out/qa-agent-timeout/run.py`

Mandatory when accepting this isolated backend/API timeout facet. The closest native suite ran once:19 PASS,0 test skips,0 package skip events,0 failures; its temporary schemas were removed and selected public tables unchanged. Native disposable-schema role/block/expiry/race/worker-failure tests are not physical or production evidence.

Ownership/cost: zero new users. Existing controlled administrator/member accounts were checked; target/control initially had no timeout rows, active leases or pending revocations. Five own new API sessions, one own category/TEXT/VOICE, three explicit logical leases and six synthetic messages were used. The existing authorized A/B DM pair was reused; its original content/pair was preserved. No media participant joined, no RTP/audio/capture/upload workload was generated.

Cleanup: normal lift restores target timeout absence; matching own leases released, own unclaimed work and three lease rows removed, category/channels and own TEXT/DM messages removed, five new sessions revoked with protected401 readback and deleted by exact account/public-ID guards. All11 selected table count/hash baselines match before; nine service IDs/images/configurations/start times and zero restarts, source/native inputs and all earlier frozen packets remain unchanged; health200. Topology revision42→45 and13 bounded audit metadata rows are expected retained effects. This is selected-table preservation, not entire-database equality.

Evidence: summary.json, runtime-checks.json, policy-result.json, dispatch-observations.json, pending-limit.json, native-result.json, before.json, image-binding.json, cleanup.json, public-review.json and integrity.json. Private credentials, JWTs, account/session/lease/message/DM IDs, body strings and logs stay excluded. No controller/native/runtime failure occurred in this packet.

Slavik Gym report: route=voice/manage_voice_timeout; packet=I287.C9-isolated-timeout-policy; tokens=estimated:9500; method=manual_estimate; driver=timeout-lease-session-and-chat-boundary; next_split=actual-SFU-issued-JWT-and-native-dialog-acceptance.
