# Screen sender telemetry v1

`ScreenTelemetryEnvelopeV1` is short-lived sender diagnostics for the selected
screen viewer. It is separate from `ScreenShareDescriptorV1`, which remains
publication configuration and lifecycle metadata.

## Publish and authorization

An authenticated sender posts one bounded envelope to
`POST /api/v1/voice/leases/{ownerLeaseID}/screen-telemetry`. The normal secure
session cookie and deployment Origin boundary apply. The server verifies the
owner's active lease and session, then asks private LiveKit management for the
active screen publication. The current descriptor's account, room,
`media_session_id`, and `publication_generation` must match the authenticated
owner and envelope.

The server obtains viewer lease IDs only from the short-lived screen-viewer
selection store. It rechecks those exact leases against PostgreSQL for an
active session, an open VOICE channel shared with the owner, and unblocked
accounts. Only the reauthorized viewer accounts receive the event. The event
contains the opaque owner lease and publication scope so a client can filter
its selected screen. It never contains a track SID, account name, client IP,
SDP, SSRC, token, window title, or media bytes.

## Lifetime and limits

- The request body and relayed event are bounded to 2 KiB.
- Samples are accepted no more often than once per 2.5 seconds for the same
  publication; senders should target 3–5 seconds.
- The Go gate retains only sequence/rate-limit state, with a 15-second expiry
  and a 4,096-entry cap. It does not retain sample values.
- Realtime delivery uses `screen_telemetry_v1` capability gating and the
  transient event-hub path. It bypasses the replay journal. Queued samples for
  the same publication coalesce to the newest value; when a subscriber is
  congested, normal bounded realtime overflow handling applies.
- No sample is written to PostgreSQL, metrics, a durable event journal, or a
  telemetry log. A new viewer receives telemetry on the next sender sample;
  reconnect does not replay an old sample.

The current Web and Flutter clients do not yet request this capability or send
the envelope. Their integration and platform capability matrix are in PR6;
viewer aggregation and paired runtime evidence are in PR7. Missing or
unsupported values must remain explicitly unavailable. This contract is not
evidence of hardware support, media quality, capacity, or device acceptance.
