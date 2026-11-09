# Issue 689: Python verification diagnostics

- FAIL: running the complete tool suite with Windows Python produced 14 failures,
  53 errors and 39 skips, including POSIX/macOS-only operations. It also exposed
  historical artifact and signal-catalog drift, which were corrected separately.
- PASS WITH SKIPS: on a Linux filesystem copy based on `72928320d`, with all
  then-changed and untracked files verified against the dirty worktree by SHA-256,
  1,417 Python tests ran with zero failures and errors. Twenty-seven were skipped:
  18 require macOS codesign/Cocoa and nine require isolated Tempo runtime opt-in.
- The Linux run used Python 3.14 and a task-local environment with the pinned
  OpenAPI validator, not the CI-pinned Python 3.12.15. It preceded later source
  changes and is diagnostic evidence, not final `check:contracts` or release proof.
- PASS WITH SKIPS: a subsequent verified dirty-source Linux snapshot ran the
  project-owned suite with Python 3.12.15 and CI-declared dependencies: 1,417
  tests, zero failures/errors, 27 skips. It also preceded later source changes;
  skipped platform/Tempo checks and the final contracts gate remain open.
- PASS WITH SKIPS: `python -m tools.ci.native.contracts` on a newer SHA-256
  verified dirty snapshot using Python 3.12.15 exited 0: 1,417 Python tests
  with the same 27 skips, realtime guard with zero findings, 135 OpenAPI
  operations, contract and approved-brief traceability checks. The snapshot
  predates subsequent changes; the skipped cases are not acceptance evidence.
- PASS WITH SKIPS: after the Android listener scenario and maintenance pacing
  change, the native contracts command was repeated on a verified dirty overlay
  in the persistent Linux snapshot: 1,421 Python tests, 27 skipped, zero
  failures; realtime guard, OpenAPI parity and approved-brief traceability also
  passed. This is not an immutable candidate or a substitute for skipped tests.
- NOT_RUN: skipped macOS and isolated Tempo cases, final immutable revision and
  exact CI environment. The source snapshot and private logs are local-only.
