# Issue 687 Web Auto Safety Stage

> **For agentic workers:** Execute the bounded tasks sequentially with focused behavior tests.

**Goal:** Add a safe internal Web Auto selection path while preserving existing user preferences and release guards.

**Architecture:** Resolve an explicit Auto request to WebRTC unless a local research v0.2 build and capability checks permit RNNoise. Keep requested and effective modes distinct, use the existing serialized fallback and mute lifecycle, and never auto-enable DeepFilter without a performance preflight. This stage does not expose a UI or claim adaptive or cross-platform acceptance.

**Tech Stack:** Vue/TypeScript, LiveKit, Vitest.

### Task 1: Selection and requested/effective behavior

**Files:** `clients/web/src/voice/noise_suppression/types.ts`, `capabilities.ts`, `microphone_adapter/profile.ts`, nearest Vitest tests.

- [x] Test explicit Auto migration, browser fallback, research-only RNNoise selection, and explicit OFF preservation before implementation.
- [x] Resolve Auto on the existing microphone lifecycle; preserve requested Auto during processor state changes and fallback.
- [x] Run focused tests, type checking and existing microphone lifecycle tests; document remaining acceptance.

### Task 2: Acceptance boundary

- [x] Attempt applicable local feature real-stack gate and record the blocked result.
- [ ] Keep UI, Windows Auto, dynamic adaptation, licensed models, real-speech tests and release gates open until independently implemented and verified.
