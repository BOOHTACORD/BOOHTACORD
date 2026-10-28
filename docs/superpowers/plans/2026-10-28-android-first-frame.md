# Android stationary first frame implementation plan

> **For agentic workers:** Execute this bounded plan task by task in this chat.

**Goal:** Reproduce #584 on the signed Samsung candidate and deliver a first image from a stationary app-only source without scrolling.

**Architecture:** Keep MediaProjection, voice, ACL and signing identities unchanged. First establish fast/delayed picker behavior with two real receivers. Localize capture versus encoder/receiver readiness before selecting the smallest capture-path correction.

**Tech Stack:** Flutter, vendored flutter_webrtc Java, WebRTC, LiveKit, Android 16, Chrome.

## Operating brief

- workflow_class=split_first; task_size=medium; structure_mode=structure_no_rg.
- Verification route: T-036 screen publisher lifecycle, Samsung app-only initial image; dependencies T-031/032/033/034/022. Separate implementation, physical verification and branch/PR packets.
- Exact edges: Flutter screen/capture/driver.dart → getDisplayMedia → GetUserMediaImpl.java → OrientationAwareScreenCapturer.java → VideoSource observer → LocalVideoTrack processor → publisher. Receiver counters come from two owned Chrome MEMBER sessions.
- Preserve: voice/microphone, public Display source only, orientation/profile cadence, stop cleanup, source visibility privacy, no stored media/audio or credentials in evidence.
- New leaf files target100/hard120 lines, target8/hard16 production and direct tests. Existing oversized native bindings are integration edges; no unrelated conversion.
- Checks: focused Java behavior regression, Android plugin tests, relevant Flutter contracts, screen feature real-stack check, signed physical before/after. Source-resolution screenshot inspection records visible result.
- Stop condition: three fast/delayed stationary-source cycles, first RTP/decode/presentation without scroll, stop/restart retains voice and releases projection/FGS/polling; issue remains open for any missing required evidence.
- Unknowns: capture vs encoder readiness, delayed-picker specificity, current backend revision, signing candidate availability. Never subtract clocks from different devices.

## Tasks

- [ ] Repeat baseline fast and delayed source selection; retain safe milestones and receiver counters, including failures.
- [ ] Inspect the concrete native capture/encoder boundary; choose a fix only from observations and upstream API semantics.
- [ ] Add failing tests for stationary first-image recovery, visibility, bounded scheduling and cancellation before implementation.
- [ ] Implement a focused native leaf and wire its exact capture lifecycle edges. Register the screen feature scenario and native test inventory.
- [ ] Run focused checks and the registered real-stack command; record unavailable targets explicitly.
- [ ] Build a signed source-bound candidate through the existing trusted delivery path, preserve installed session, and repeat physical scenarios.
- [ ] Record sanitized evidence, review changed files/status/sizes, deliver through PR and verified CI. Merge is already authorized by the owner; close #584 only after its acceptance criteria pass.
