# Issue 687: Windows DeepFilter through isolated LiveKit

At parent source `4f00abd9fece9b7993420fcef6c4adcf18340442` with the
`tools/audio/windows_livekit_probe` files in this packet, an unsigned Windows
Flutter diagnostic published a physical microphone to a second participant in
the same process via an isolated local LiveKit v1.13.7 instance. The server's
Windows archive SHA-256 was
`e539e7d2f75807b9c9202cd2a0bf2cb3d52fc4c52978a6953e0f47bc339fe77f`.
Signaling bound to loopback; RTC candidates were restricted to the host's
private interface. Tokens and server keys were short-lived and were not logged.
The temporary server was stopped and its key configuration removed. No audio,
SDP, candidates or user identifiers were saved by the probe.

A first configuration advertising only loopback failed ICE before media
connection, reproducing an earlier browser-side test limitation. Restricting
candidates to the host's private interface allowed the two local participants
to connect. A repeated run of the checked-in probe published and subscribed
successfully: 157 RTP packets and 21,833 bytes were received, while native
capture reported 16 kHz mono, 936 DeepFilter frames and zero fallback frames.
The diagnostic disabled receiver-track volume after subscription.

- Probe executable SHA-256: `ef74895de1aa784730dae8d117dd5e7c2e2551df38f4f3531312beec0b39fb42`.
- WebRTC plugin SHA-256: `c39067a55f3c95bb38143e18fac5e222a3f1db3109ff209a34916485d10c6644`.
- Aggregate result SHA-256: `35782b7def9220f348d770313067a7c9f592404cb85c34bc80e233d60240ec65`.

The model and DLL are research artifacts pinned in the prior Windows owner
evidence. This is one approximately 10-second run, with two SDK rooms in one
process, not the BOOHTACORD application UI, a second physical device, a
human listening assessment, 30-minute stability, a signed installed client or
production. These acceptance gates remain NOT_RUN. No server was deployed.
