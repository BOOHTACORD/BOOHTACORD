# ADR-032: Proposed native DeepFilterNet processing boundary

Status: proposed for issue #687; not implemented or approved for release.

## Context

The existing Windows WebRTC capture postprocessor is downstream of the
platform's AEC and AGC (ADR-014); changing this ordering is not assumed. A
local libDF experiment observed allocations on every processed frame and its
stock C API can panic on errors. Calling that API directly on the capture
callback therefore does not meet the requested callback contract. Independent
measurements and limits are recorded in
`evidence/voice/issue-687-deepfilternet-research-2026-11-13.md`.

## Proposed boundary

- Prepare and warm a pinned native model outside the audio callback. Validate
  the library, model, licensing and actual input format before activation.
- Transfer fixed 480-sample mono 48 kHz frames through bounded single-producer,
  single-consumer queues. The capture side must not allocate, wait on a mutex,
  load files, initialize a model, or perform inference. A non-realtime worker
  may allocate only within a measured and bounded resource budget.
- Carry generation and sequence metadata. Discard stale results after mute,
  leave, reconnect, switch, reset or device change. Zero or disable output
  until the current processed generation is valid; never silently publish raw
  PCM contrary to mute or deafen intent.
- Signal overload, unsupported format and initialization/processing failure to
  the existing serialized capture owner. It must restore the standard engine
  within a measured bound or keep transmission muted and explain failure.
  Queue capacity, underflow threshold, wake strategy and transition timing are
  not yet decided and require measured tests on supported Windows hardware.
- Use one noise-suppression engine at a time. Preserve independent AEC/AGC,
  device selection, screen audio and existing account preferences. Do not use
  a Python service, an external executable or a virtual microphone.

## Release gate

The queue currently exists in isolation only. Before this proposal becomes a
decision, implement and test worker ownership, a non-panicking C boundary,
bounded overload and teardown, source/weight provenance, lifecycle races and
independent rollback. Validate callback allocations and timing with a real
Windows build, plus the speech, listener and end-to-end checks in #687. Record
GO/NO-GO separately for RNNoise and DeepFilterNet; do not infer acceptance from
unit tests or a standalone model benchmark.
