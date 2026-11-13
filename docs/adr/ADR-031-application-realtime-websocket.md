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
Web workspace notification delivery and follow-up edited-message refreshes are
also fenced to the socket incarnation that started the work. In-flight store
requests themselves still require independent cancellation or stale-write
protection; this fence does not establish that broader guarantee.

Web authenticated socket attempts allow 15 seconds to receive
`connection.ready`. A session revalidation on retry is bounded to 10 seconds
and aborted on timeout or ownership change; an inconclusive check is not treated
as proof of logout. Initial-roster availability and silent-connection liveness
have separate requirements and are not proven by this deadline.
Flutter uses the same 10-second session-revalidation bound. Timeout, explicit
close and manual replacement abort that HTTP request; a cancelled or late
response cannot by itself expire the replacement connection.

The server can emit a payload-free heartbeat every 15 seconds on public and
authenticated sockets that negotiate `boohtacord.heartbeat.v1` as a WebSocket
subprotocol. Legacy connections receive no new event. Web requests the
subprotocol and expires a ready socket after 45 seconds without a valid event;
it also checks elapsed silence when a page becomes visible and reconnects on a
browser online notification. If protocol negotiation fails before opening, Web
alternates the next attempt with a legacy handshake, and tries the modern
protocol again after an established connection closes. A legacy connection has
no heartbeat-based silence detection; a transient handshake failure can also
lead to this fallback. Flutter requests the same protocol, checks its payload-free
heartbeat and reconnects after 45 seconds without one, including an elapsed-time
check on app resume. Android emulator loopback covers this narrow path; actual
background/network switching, mixed-version rollout and production rollback
remain separate release gates.

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
