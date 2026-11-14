# Issue 687 Native Auto Safety Stage

> **For agentic workers:** Execute each task with focused tests before implementation.

**Goal:** Preserve an explicit internal Auto preference and safely resolve it to native WebRTC suppression until model identity and performance preflight are proven.

**Architecture:** Add a serialized mode without changing existing defaults; request browser suppression for Auto on all platforms and preserve requested/effective diagnostics. Keep Auto out of the normal selector unless an existing saved preference requires rendering it. This is an internal stage, not neural-engine adaptation or a release.

**Tech Stack:** Flutter, Dart, native audio method channel.

### Task 1: Safe migration and resolution

**Files:** audio preference enum and serializer, native prepare, selector, focused Flutter tests.

- [x] Test Auto migration, default/explicit OFF preservation, native browser resolution and method-channel request.
- [x] Implement safe browser resolution and prevent the unfinished mode from appearing as a new choice.
- [x] Run focused Flutter audio, widget and static-analysis tests; document real-stack limitations.

### Task 2: Remaining acceptance

- [ ] Implement model-aware engine selection, performance and sustained-noise adaptation, UI, device and acoustic acceptance before release.
