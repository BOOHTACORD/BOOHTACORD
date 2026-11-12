# ADR-031: Application realtime over WebSocket

- **Status:** Accepted for the issue #689 implementation; release gates pending
- **Date:** 2026-11-09
- **Supersedes:** ADR-015 long-lived voice roster SSE after coordinated cutover

## Decision

Use one application WebSocket per client instance in steady state. Before login,
the public socket carries only connection and maintenance state. After login,
the authenticated socket carries maintenance, authorized roster and existing
replayable application events. LiveKit signalling and media remain separate.
REST continues to serve commands, history and one-shot diagnostic reads.

The maintenance observer reads authoritative state centrally, including changes
made outside the API process. A bounded roster coordinator uses verified
LiveKit webhook hints and periodic reconciliation; PostgreSQL ACL and active
leases remain authoritative. Per-recipient delivery rechecks session and access.
Roster and maintenance events are ephemeral and never advance the durable replay
cursor. Unknown dependency state is unavailable, not an empty roster or an
inactive maintenance flag.

Roster generation identifies one live account-coordinator incarnation. All
concurrent subscriptions to that account share it; removing the last subscriber
discards the account state, and the next incarnation obtains a new UUID before
its revision starts again. A new process also creates new incarnations. The Web
delivery queue is invalidated at each socket disconnect; its last successfully
applied durable cursor remains available for replay. These rules do not by
themselves cancel side effects of already-running protected REST requests.

Web authenticated socket attempts allow 15 seconds to receive
`connection.ready`. A session revalidation on retry is bounded to 10 seconds
and aborted on timeout or ownership change; an inconclusive check is not treated
as proof of logout. Initial-roster availability and silent-connection liveness
have separate requirements and are not proven by this deadline.

The public socket uses bounded admission and the configured Origin policy. No
public event carries protected account, roster, session or message information.
The deployment remains one guild and one application API process; this decision
does not establish multi-instance fanout or a media capacity claim.

## Rollout constraints

Removing the old routes requires a compatible release sequence and an explicit
old-client update/denial mechanism. A supported old client must not silently lose
maintenance or roster updates. Preserve signed compatible artifacts and verify
rollback, observability and schema compatibility before production cutover.
This ADR records the target decision; it does not assert that those gates,
physical-device acceptance or production deployment have passed.

Existing historical evidence describes the previously deployed SSE design and
must not be rewritten as proof for this architecture.
