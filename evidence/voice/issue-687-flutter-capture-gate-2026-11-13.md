# Issue 687: experimental Flutter capture gate

The Windows Flutter selector is hidden unless the experimental compile-time
flag is enabled. Its normal release still lacks a bundled, instantiated native
model and must not advertise DeepFilterNet as operational.

A 97-test Flutter audio-device and voice regression run passed. Focused tests
use fake tracks and method channels to check model preflight, cancellation,
falling back to WebRTC before capture or unmute, and input-device switching.
These are component tests, not a physical microphone or LiveKit call. Real
Windows device-change ordering and actual model processing remain unverified.
The client-parity manifest verification passed against base
`02dd970d62ca1a349b50cb9a3df363cbc181a3a9`.

Flutter component screenshots at 1100 and 393 pixels rendered unreadable test
font glyphs; visual acceptance is NOT_RUN. The local-features runner offers no
Windows target. A real-stack attempt reported web-unit and web-build BLOCKED
on this Windows host and Docker did not answer within 12 seconds. No production
server was deployed. Full native, audio-quality and long-duration gates remain
BLOCKED or NOT_RUN; this record does not authorize issue closure.
