# POC-03 actual-media revoke/replay acceptance (#59)

Run `python3 -m tools.qa.media_revocation.run` from an isolated QA checkout with
the repository's locked Web dependencies, Node, Docker and an explicitly selected
local Docker context/configuration. No production account or deployment is used.

The runner reuses the existing mini-player API/PostgreSQL/Tempo/LiveKit fixture
on loopback ports 4830/4832/4833/4883/4884/4885. It preserves the **production
Caddy `/rtc` forward-auth route**, changing only owned upstream names and static
fixture serving. Management remains inside the owned Docker network. The SFU
image is pinned to the repository digest; the running image ID is also recorded.

Two independent Chromium contexts use the actual locked LiveKit SDK. The
presenter publishes a moving 640×360 canvas and a quiet 440 Hz tone. A third,
administrator session performs real API mutations. The receiver must observe
decoded video frames and inbound audio packets before each of seven actions:
kick, ban, logout, session revoke, password reset, transfer and channel close.
There are no fabricated API responses, media connections or worker outcomes.

The SDK credential is observed from the actual engine `tokenRefreshed` event
and must differ from the API-issued credential. Both remain only in memory.
The identical raw upgrade probe must accept each credential with HTTP 101 while
the lease is active. These positive probes run before publication because a new
connection with the same identity replaces the old SFU participant. The actual
SDK connection is re-established and received video/audio verified afterward.
After authoritative lease revocation, the runner waits for the durable worker's
confirmed dispatch, presenter disconnect and receiver track unsubscribe. Each
unexpired credential is independently replayed through a real TLS WebSocket
upgrade handshake to `/rtc`; **both must return 403**, rather than an expiry,
network error or missing result. The replay probe trusts only the owned Caddy CA.
The browser fixture uses an explicit local certificate-error exemption and does
not claim production certificate/trust-chain acceptance.

The observer's connection and live lease survive individual revocations. Closing
the channel deliberately revokes both participants and must reach room-empty or
finalized with no pending revocations. Old session cookies are replayed against
the protected `/me/sessions` route; `/auth/session` is optional authentication and
its HTTP 200 cannot prove a cookie remains authorized. Session mutations supply
the expected account header. Ban denies login, reset links reject reuse, and
kick/transfer permit an explicit new lease/connection without reviving the old one.

Receipts and synthetic screenshots are under `.out/issue59/runtime`. Previous
attempts are archived before starting a fresh RUNNING result. A failed check
cannot inherit an earlier PASS. Images are ignored generated artifacts; inspect
them at source resolution and publish only sanitized metadata in `evidence/`.
No cookie, credential, account/room/lease ID, query URL, raw SDK log, HAR or
private message is included. Every temporary file and labelled service is removed
in cleanup. A hard timeout stops the owned Node/Chromium process group using the
existing tested process owner. Foreign containers/processes are never stopped.
The fixture respects the normal 10-logins/5-minute source quota: a 429 login
waits for the numeric `Retry-After` once (at most 300 seconds). Missing, invalid
or excessive backoff fails closed; neither limits nor identities are rotated.

Focused regressions (also discovered by the project Python CI gate):

```sh
python3 -m unittest tools.qa.media_revocation.test_evidence \
  tools.qa.media_revocation.test_proxy tools.qa.media_revocation.test_request
```

The fixture's 45-second observation timeout is a bounded test guard, not a new
product SLO. The current production revoke worker polls every 15 seconds; record
the actual measured delay. Received packets do not establish subjective audio
quality, capture FPS capacity or physical-device acceptance.
