# Issue 689 internal roster lease proof

**Goal:** Retain the exact LiveKit-matched lease for each participant so outbound delivery can recheck that lease, without exposing it in HTTP or WebSocket JSON.

**Route:** `backend/internal/voice/list_connected_participants`, preserving its existing double PostgreSQL check and output shape.

- [x] Test that the matched lease is retained internally and omitted from serialized roster data.
- [x] Confirm RED; retain the proof without changing the public participant contract.
- [x] Run existing service tests and PostgreSQL integration; outbound authorization is a separate packet.
