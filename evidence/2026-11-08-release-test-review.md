# Release test review, 2026-11-08

Scope: release publisher tests, the Go backend test inventory, and Flutter app and vendored LiveKit/WebRTC tests. This record does not certify every assertion's semantic value.

- Go AST inventory: 791 `internal` test files, 1,334 test functions; seven `cmd` files, 11 test functions. Three functions without direct failure calls are an assertion helper caller and two subprocess helpers. A literal-constant search is not a proof of test effectiveness.
- Flutter AST inventory: 530 `_test.dart` files and 1,961 direct `test`/`testWidgets` calls. The scan identifies candidates, not every dynamically generated test or indirect assertion. Visual captures and platform-specific tests are retained for their separate purpose.
- Text and byte stream tests now wait for delivery and verify bytes, metadata, operation types, attachment contents, and progress callbacks. They use temporary files for the updated file scenarios. Wrong text, a wrong generated flag, a missing stream handler, and an unobserved progress callback were each injected in a disposable test copy; each mutation failed as expected.
- Windows Flutter app: 1,810 passed, three platform/fixture-dependent skips. LiveKit: 453 passed, three skips (two require macOS; a pre-existing disconnect/reconnect test is marked `todo`). A disposable copy of the latter timed out after five seconds when unskipped; its cause is not established and it is retained. Flutter WebRTC: 34 passed. LiveKit stream file: 17 passed. Focused Flutter static analysis: no issues.
- Go: PostgreSQL 17.6 disposable container; `go test -json -count=1 ./...` on backend tree identical to the reviewed revision; event verifier reports 1,780 passed, zero skipped, zero failed. The command's initial wrapper returned failure because its verifier path contained a carriage return; independently rerunning the verifier on the original events passed. Temporary container removed. Go toolchain 1.26.4.
- Publisher tests: 17 Node tests and three workflow tests passed. The current native publisher CLI rejects missing tokens on all three platforms.

NOT_RUN: full macOS native runtime; real device/media acceptance; hosted CI for these unmerged changes. Source execution and test results are not production deployment proof.
