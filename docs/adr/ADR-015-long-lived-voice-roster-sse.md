# ADR-015: Long-lived voice roster SSE with session revalidation

- **Status:** Accepted
- **Date:** 2026-10-02
- **Decision owners:** Voice Platform maintainers

## Context

The roster endpoint previously closed each Server-Sent Events response after
10 seconds so the browser would reauthenticate on every reconnect. This made
the browser open a new HTTP request roughly every 13 seconds even when the
workspace and network were healthy. Those requests were valid SSE connections,
but the repeated churn was unnecessary and obscured actual reconnects.

Keeping a stream open without rechecking its session would leave a revoked
session attached to an authenticated stream. Roster snapshots must also keep
applying the caller's current channel visibility and active voice leases.

## Decision

Keep one SSE response open for the lifetime of the client connection. Send
comment heartbeats every 15 seconds so idle connections remain active through
the reverse proxy. Revalidate the original session cookie every 10 seconds
using the existing session authenticator. Continue rebuilding each roster
snapshot through the existing ACL and LiveKit presence service. Signed
LiveKit webhooks request an immediate refresh, and each open stream also
reconciles its snapshot every 4.75–5 seconds with per-stream jitter. Send a
snapshot only when its
serialized roster changes so a missed or delayed webhook cannot leave the
browser stale indefinitely.

If the session is revoked or no longer resolves to the original account and
session digest, send an `event: session-expired` frame and close the response.
Web and Flutter clients close the stream and use their existing session expiry
handling. A session-store error closes the response without emitting roster
data; the clients may retry through their normal connection recovery paths.

## Consequences

- A healthy workspace uses one roster HTTP request until the browser or client
  disconnects or the session expires.
- Session revocation is detected within the 10-second revalidation interval.
- The server performs a bounded session lookup per open roster stream every 10
  seconds and an ACL/lease recheck per refresh. SFU observations share only
  equivalent scopes under the bounded gate; authorization stays per caller.
- Network failures still cause normal SSE or client-stream reconnects.

## Bounded recovery and observation cost (2026-10-08, #268/#269)

Initial mandatory dependency failures return 503 with `Retry-After: 1` and the
server-generated `X-Request-ID`. SSE keeps its stable `roster unavailable` text;
GET keeps the existing error envelope. Known SFU validation/token defects are
500. Auth middleware retains 401; visibility and active leases remain DB truth.
Internal bounded stages identify DB initial/recheck, SFU room/participant,
validation, timeout/cancel and session-store failures without public details.

Refresh performs at most one retry after 300–399ms jitter within the original
five-second deadline. Exhaustion emits `roster-unavailable` with `{}` then closes;
no fake empty result or session-expired event is emitted. Cancellation stops the
retry timer. Session revalidation and heartbeat schedules are unchanged.

The SFU observation gate holds at most four active exact-equivalent scopes and
16 cached scopes. It never bypasses its budget and has no waiting queue. Its
250ms success TTL and failure cooldown never retain partial/error payloads.
All-waiter cancellation aborts the shared three-second fetch; one canceled
waiter cannot cancel observers still using it. Verified webhook invalidation
clears retained observations and prevents pending observations being cached.
Current per-user ACL and leases are checked both before and after every read.
Periodic reconciliation recovers missed notifications without exceeding five
seconds plus a bounded snapshot duration. Snapshot costs are coalesced only
for equal scopes; different authorized scopes are never merged.

Synthetic fanout tests/benchmarks demonstrate the software budgets only.
Production 1/10/25/50/100 watcher by 0/1/5/20 room baselines, latency/error/DB
wait, CPU/RAM and device freshness acceptance remain separate evidence work.

## Initial authentication and REST database bounds (2026-10-13, #272)

The active-session database lookup uses the existing five-second snapshot/session-revalidation budget. An earlier caller deadline still wins. This lookup context is released after authentication; the original authenticated request context remains live for SSE heartbeats, reconciliation and session revalidation.

REST roster snapshots also receive a five-second child context so initial visibility and post-SFU lease/ACL database reads cannot wait indefinitely. Successful empty and populated results remain authoritative snapshots. On the two roster endpoints, an initial session lookup deadline returns 503, Retry-After: 1 and the standard VOICE_PRESENCE_UNAVAILABLE JSON error envelope with the request ID. Other authentication errors retain existing 401/500 semantics. SSE initial snapshot failures retain their existing plain-text body; no dependency failure is converted to an empty roster.

These software deadlines do not assert a deployment latency SLO or close device, load, production or rollback acceptance gates.
