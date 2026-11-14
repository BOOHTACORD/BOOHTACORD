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
- This ADR defines application activity rather than operating-system-wide
  idle time, which browsers cannot reliably expose across platforms.
