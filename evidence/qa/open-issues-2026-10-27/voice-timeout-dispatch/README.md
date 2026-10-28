# Actual dispatcher: one absent-participant revocation intent

**PASS_SCOPED backend runtime.** One normal API timeout created one owned durable revocation intent. During a full35.203-second observation (minimum35, hard limit40), the real worker completed one attempt without an error; GET pending changed true→false while the timeout remained active. DB requested-to-completed latency was5.342334s; the first completed sample was observed at6.265s. No RTC participant or media credential was created, so actual eviction and old-JWT reconnect remain NOT_RUN.

Route: backend/internal/media/dispatch_voice_sfu_revocation, its worker subleaf, app/worker_runtime.StartVoice and lifecycle/periodic. Source uses a15-second ticker,5-second dispatch context and batch100. The initial queue was empty, so backlog did not delay this owned item. The scenario maintained the full35-second minimum even after completion was observed.

| Invariant | Actual result |
|---|---|
| Own fresh lease and timeout intent | Logical lease201; timeout202, active=true, revoked_leases1, pending=true |
| Real scheduled consumption | attempt_count1, completed=true, claim cleared, last_error_code=null; no manual worker invocation or direct queue update |
| GET pending follows terminal state | Thirty HTTP200 samples, timeout active throughout; initial pending=true, final pending=false; no pending-false/pre-completion mismatch observed |
| Full bounded observation |35.203s, thirty samples; first attempt/completion observed6.265s; DB latency5.342334s |
| Normal lift and exact owned cleanup | Lift200 active=false/pending=false; one owned lease/intent, VOICE/category and two own sessions removed; protected401 readback |

Platform: existing private boohtacord-local-qa API/Web images declaring source072426d60b1c0b1f7e5f66722a0da5faa00b50d7, PostgreSQL17.6 and configured LiveKit RoomService. Fresh guards verified nine running loopback services, image revisions, finite database/endpoint/key/secret presence booleans, and controlled A/B initially active MEMBER accounts with no timeouts, active leases or pending revocations. Values, URLs and credentials are private. No role, clock, source, global config or restart mutation occurred.

The dependency assessment reads exact backend/go.mod/go.sum: LiveKit protocol1.49.0 and management/protobuf dependencies are pinned, plus Pion4.2.11; no LiveKit server-sdk-go RTC client is declared/locked. Protocol's RoomService client is not a Room.Connect RTC client. No dependency/software/cache-only SDK was added and no custom signaling client was built. The explicitly authorized no-participant branch was used. Management completion can represent an already-absent participant and cannot establish media eviction.

Commands executed:

1. `python -B -X utf8 .out/qa-agent-timeout-dispatch/preflight.py`
2. `python -B -X utf8 .out/qa-agent-timeout-dispatch/native.py`
3. `python -B -X utf8 .out/qa-agent-timeout-dispatch/run.py`

Mandatory when accepting the actual backend dispatcher/pending facet of I287.C9. Full I287.C9, real SFU participant removal, already-issued JWT direct reconnect, native/Web dialogs and physical/production acceptance remain PARTIAL/NOT_RUN. The earlier55-control/19-native packet is unchanged and is not retroactively upgraded.

Native supplement: the different nearest worker suite ran once, eight PASS events including two subtests, zero skip/failure events. It covers repository claims/confirmation/retry, removed/absent outcomes, truthful unavailable-pending behavior, bounded context/batch and safe causal tracing. The previous19 timeout tests were not repeated. Native unit mocks and the real scheduled absent-participant receipt are separate evidence levels.

Cleanup PASS: zero new users; two normal new sessions on existing controlled accounts. Target timeout absence restored by normal lift; own lease/intent removed only after receipt capture, own VOICE/category removed, sessions revoked with live401 and deleted by exact new public-ID/account guards. Nine selected table count/hash baselines match before. Nine service IDs/images/configurations/start times, source/native inputs and all previous frozen packets remain unchanged; health200. Topology revision45→47 and five own audit metadata rows are expected retained effects; this is not entire-database equality.

Evidence: dispatch-result.json, observations.json, intent.json, normal-lift.json, cleanup.json, native-result.json, dependency-assessment.json, before.json, summary.json, public-review.json and integrity.json. Public records contain metadata/hashes only; raw account/session/lease/channel IDs, cookies, environment values and logs stay private. Optional source filename discovery noted an absent service.go and followed exact client.go before execution; no controller/native/runtime failure occurred.

Slavik Gym report: route=media/dispatch_voice_sfu_revocation; packet=actual-dispatch-absent-participant; tokens=estimated:7000; method=manual_estimate; driver=scheduled-worker-and-pending-transition; next_split=pinned-RTC-client-and-connected-participant-acceptance.
