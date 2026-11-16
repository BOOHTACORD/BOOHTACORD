# Issue #787 PR5 — Screen telemetry relay v1

## Scope and result

This record covers the backend and contract slice for PR5 only. The relay accepts
bounded sender envelopes from the authenticated owner lease, verifies the
current LiveKit screen publication scope, and rechecks every selected viewer
lease against PostgreSQL before private realtime delivery. Events are transient,
capability-gated and coalesced; samples are not persisted or journaled.

## Verification

- **PASS** — targeted Go tests for `screen_telemetry_relay`, viewer presence,
  LiveKit publication verification, event hub, media routes and runtime wiring.
- **PASS** — Go race tests for the relay, API, bounded memory gate, viewer
  presence store and transient event hub.
- **PASS** — realtime telemetry schema tests (`3` tests).
- **PASS** — OpenAPI parity (`138` public operations, `4` private exclusions).
- **PASS** — focused PowerShell telemetry contract assertions.
- **PASS** — `git diff --check`.
- **PASS** — full `verify-contracts.ps1` with its pinned OpenAPI dependency
  installed into an isolated `/private/tmp` target: 29 tests, OpenAPI 3.1 lint,
  parity and all PowerShell contract assertions pass.
- **BLOCKED** — supplemental `python -m tools.ci.native.contracts`: its broad
  suite requires unavailable `cmake`, Docker behavior, disposable service
  fixtures and localhost binds. The targeted contract verifier above passes;
  hosted PR CI remains the complete cross-platform gate.
- **BLOCKED** — `go test ./...` first hit unrelated existing `httptest` cases
  that cannot bind localhost in the sandbox. A loopback-enabled rerun completed,
  but unrelated load-profile tests then failed against the absent disposable API
  test environment (HTTP 503). All targeted packages for this change passed
  separately; hosted CI remains the complete backend gate.
- **NOT_RUN** — paired Web/Flutter sender-to-viewer real-stack checks. Client
  sender integration and viewer aggregation are later issue stages (PR6/PR7).
- **NOT_RUN** — physical-device media quality, hardware support and capacity.
  This contract/backend slice provides no evidence for those claims.

## Security and privacy coverage

Focused tests cover strict payload decoding, bounds, unauthenticated requests,
wrong owner/publication generation, stale sequence, viewer ACL failure, exact
viewer targeting, capability gating, transient delivery and absence from the
event journal. Event payloads omit the private LiveKit track SID and session
credentials. No screen content or arbitrary text is accepted.

## Status

PR5 implementation evidence is scoped and passing as listed above. The
cross-platform and release acceptance gates remain open for PR6/PR7 and the
issue-level paired runtime evidence.
