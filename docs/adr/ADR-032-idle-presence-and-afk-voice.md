# ADR-032: Idle presence and AFK voice channel

- Status: Accepted
- Date: 2026-11-14

## Context

Presence currently distinguishes connected users from disconnected users. A
connected client can remain in a voice room after its user leaves the device.
The product needs an `idle` member status and an administrator-managed AFK room
that automatically receives inactive voice participants.

## Decision

- A connected account becomes idle after five minutes without a user-generated
  interaction. Activity is reported over the authenticated realtime connection;
  the server owns the timestamp and state transition. If an account has multiple
  connected clients, any recently active client keeps the account online.
- User activity includes pointer, keyboard, touch, scroll, and resumed-app
  interaction. Backgrounding an app does not itself claim that the person is
  idle; the normal inactivity timer applies.
- AFK routing is disabled by default. An administrator may select an active
  voice channel and an inactivity interval from one minute through 24 hours.
  The interval is measured from the last server-observed activity.
- The server revokes the participant's old lease before notifying its owning
  client to reconnect to the configured AFK room. A reconnect uses a fresh
  session-bound lease and room token. Moving an idle user never creates a lease
  for a disconnected client.
- Every lease in the configured AFK room receives a LiveKit grant that excludes
  microphone publication. The clients show the microphone as locked and do not
  offer an enable action. Server-side token enforcement remains authoritative.
- AFK configuration remains one-guild data in `guild_settings`, uses the
  existing administrator session, Origin/CSRF checks, revision conflicts, and
  metadata-only audit. No global presence, public media payload, or additional
  media relay is introduced.

## Consequences

- Presence idle state is transient and resets to online after a client
  reconnect; it is not a durable profile preference.
- Existing clients that do not understand idle continue to see the account as
  online. Updated clients display a distinct idle group.
- AFK destination selection is valid only while the referenced channel remains
  an active voice channel. The server skips routing when that channel is
  archived or admission is closed.
- The original decision used application-scoped activity. The amendment below
  defines platform-specific system activity where supported.

## Amendment: platform-aware activity (issue #790, 2026-11-18)

Desktop clients should account for system input outside BOOHTACORD when the OS
provides a reliable, privacy-preserving signal. Windows uses `GetLastInputInfo`
and the current session's lock state; only the aggregate observation is sent.
macOS system detection and reliable lock/sleep handling remain to be completed
and verified under the sandbox. The owner excluded macOS from the current #790
delivery on 2026-11-18; this is not evidence of macOS support. No global key or
pointer contents are captured.

Desktop Web may use Idle Detection only after an explicit user gesture grants
permission in a supported secure context. Browser heuristics and background
throttling limit its precision. Without this capability, Web continues to use
application input and actual published speech. A hidden page or lost focus is
not proof of inactivity. Android, iOS and mobile Web cannot inspect other apps;
foreground input and actual speech are evidence, while background lifecycle
alone is not an offline or AFK signal.

The optional `confirmed_activity_v1` realtime capability distinguishes a new
socket without activity evidence from a fresh activity event. An authenticated
client may send `{"type":"inactive"}` for a confirmed idle or locked state.
It carries no client timestamp, identifier or input content. The server records
its own time once per unconfirmed socket and never uses this frame to assert
online; real `{"type":"activity"}` retains its original meaning. Old clients
retain the previous connection behavior. In-memory reconnect history is bounded
and is lost on process restart or eviction, so first connection without prior
history still needs a reliable initial-state solution before full acceptance.

For Windows, the optional `initial_idle_v1` capability accompanies
`confirmed_activity_v1` only when a fresh OS sample establishes at least five
minutes since input and a known session-lock state. It prevents an idle device
from becoming active on its first socket even after a server restart. The AFK
timer starts conservatively at the server's connection time; no local input
timestamp is transmitted. Opted-in Web restores its detector before opening
realtime, with a bounded startup delay, and samples a separate five-minute
IdleDetector when supported. It can alternatively use a fresh, uninterrupted
four-minute observation following the one-minute threshold. Stale or suspended
observations are discarded. If initialization times out or the browser cannot
provide reliable initial evidence, the client retains the existing fallback.

AFK routing rechecks aggregate activity after waiting for the lease lock and
serializes the final check and database commit with activity and connection
changes for that account. Guards use a bounded set of lock stripes, so unrelated
accounts on the same stripe can briefly wait for the AFK transaction; the
periodic worker bounds its operation with a five-second context timeout.
This amendment describes the target and work in progress, not completion of the
cross-platform or physical-device acceptance matrix.
