# Issue 689: Flutter resync reason validation

Status: **PASS_SCOPED** for the unit and analyzer checks. Native runtime and full feature acceptance remain **NOT_RUN**.

- Base `e0ccbefd6d87a892913c338ca61919e73b9d5afc` plus this packet. The focused test failed on the original receiver because it accepted an empty resync payload; it passed after checking the six contract reasons and rejecting missing, unknown or extra fields.
- `flutter test --no-pub test/realtime_scope` passed 20 tests, including loopback socket-open recovery. The focused `flutter analyze --no-pub` passed after three pre-existing brace diagnostics in the touched file were fixed.
- The full Flutter unit stage passed **1811**, with **3 skipped**. The registered component stage passed **503**, but its intended capture directory was not passed across the WSL/Windows bridge, so it is not visual acceptance.
- A corrected capture retry was interrupted after 339 tests because C: fell below 4 GiB. Seventeen produced images were reviewed at source resolution. Auth and reset forms retained visible controls and error text; the 2x share dialog kept its action visible while its scroll body extended past the viewport. Support-row fixtures intentionally render sparse content with a spacer, and the screen-viewer image contains a fixture placeholder: neither proves a full workspace or media presentation. The interrupted run is **NOT_RUN** as a complete visual gate.
- The project real-stack runner failed before app startup because the Linux Docker CLI lacked buildx. Buildx 0.37.1 was then installed separately and its hash matched `tools/toolchains.json`. A second Android attempt failed before startup because another QA namespace occupied ports 4810–4820; that namespace was left untouched. No Android runtime result is claimed.
- Spec traceability passed after the backlog entry. The current run does not establish the new unified WebSocket, voice roster, iOS/macOS, load, production rollout or rollback behavior.
