# #337 — desktop update implementation and release acceptance

Started 2026-10-14; ongoing 2026-10-15. Candidate branch
`codex/issue337-desktop-updates`, based on `3e6ac963`. This is an implementation
record, not release approval. No production catalog promotion has occurred.

Publisher: locally generated Ed25519 root `boohtacord-desktop-478919e9652ab825`.
Private key is outside the repository with mode 0600, parent 0700. Only the public
root is a client asset. Apple signing identities are not used for update trust.

Adapters: Sparkle 2.10.0, Velopack native C API/packager 1.2.161, exact official
SDK archive SHA-256 pinned in the restore tool and ADR-027. macOS sandbox remains
on. macOS OS signature remains ad-hoc; Developer ID/notarization is not claimed.
Windows Authenticode is measured by existing packaging tools, not assumed.

## Checks performed so far

- PASS: publisher roundtrip/tamper/publication/CAS/key-preservation tests (3).
- PASS: focused Flutter update, checkpoint, archive, controller and draft tests
  (47 at initial integration; further regression cases being added).
- PASS: first universal macOS release builds including Sparkle and compiled
  recovery helper. Build output alone does not establish installation acceptance.
- PASS: contracts gate: OpenAPI 3.1 lint, 19 parity tests, 108 public operations.
- PASS: spec traceability: 39 requirement IDs (approved repository index).
- PASS: Go catalog/telemetry focused tests and go vet.
- Backend broad run on macOS: 1249 PASS, 5 FAIL, no skipped test cases. The five
  load-fixture tests bind additional 127/8 source addresses unavailable by default
  on macOS. The same two packages PASS on Linux Go 1.26.4 in an ephemeral container.
  This is a host fixture limitation; no load/capacity claim is made.
- Full Flutter regression found a resize-position regression in anchor restoration;
  corrected by distinguishing in-process layout memory from disk restoration.
  Focused resize regression PASS; subsequent full rerun PASS: 1370 cases,
  one pre-existing explicit skip. Final added window-bounds guard also covered
  by the focused update/workspace suite: 146 PASS.

## Required release gates still pending

| Gate | Status |
|---|---|
| Flutter regression and analysis | PASS 1370 / 146 focused; final CI pending |
| Windows native build + per-user Setup/full package | NOT_RUN |
| Actual installed macOS N → N+1 with UI/state restoration | NOT_RUN |
| Actual installed Windows N → N+1 with UI/state restoration | NOT_RUN |
| Failed-bootstrap/apply recovery on both operating systems | NOT_RUN |
| Final web, Android, iOS rebuilds and backend build | NOT_RUN |
| Published immutable packages + signed metadata + catalog promotion | NOT_RUN |

Do not close #337 or describe in-app desktop updating as accepted until the real
OS gates above pass. Unit tests and native compilation do not replace them.
