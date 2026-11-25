# FLUTTER-STARTUP-01 / FE-67: expired startup isolation

Base: a07ecade51655fe5ffceda006d7f326a0503c932. Scope: shared Flutter startup retry generation, not the full macOS Keychain acceptance gate.

- Before: four focused tests fail because a timed-out storage/platform/session/preparation attempt keeps an active ticket.
- Fix: retire that generation and invalidate feature operations before publishing the retryable error. Preserve saved credentials, previous account metadata, normal failures and the existing 20-second deadline.
- After: seven focused cases pass, including a successful retry followed by a late account, null session or failure; 162 neighboring session/app-state/realtime tests pass.
- Analyzer: `flutter analyze --no-pub --no-fatal-infos` exits 0 under the existing CI policy; baseline advisory infos are not silently removed or treated as errors. Import boundaries, source parity projection, product-map/flow generators and Dart dependency checks pass.
- Native Android saved-session retry: PASS on the owned BOOHTACORD_QA_R1_1121 API35 x86_64 emulator, production widgets and real loopback API/PostgreSQL/WebSocket, no session/storage mocks. The first real session response is held across the 10-second test deadline; the old response is released while the error screen is still visible and cannot publish an account, then manual retry restores the same saved account and the authenticated socket/maintenance are ready, and explicit logout renders the login form. No microphone or media is started.
- Visual review: all three final 1080x2400 captures inspected at original resolution. The complete timeout explanation and retry button fit; recovered workspace has no stale startup/maintenance warning; logout shows the login form. Early captures taken before the final frame were rejected and the harness now awaits settled frames.
- Local Android build: initial Kotlin incremental compilation failed across C:/Q: roots and stale daemon caches. The successful run used the existing Q: pub cache and temporary nonincremental/in-process Kotlin settings in this isolated worktree; the original Gradle file was restored. CI must build with the checked-in configuration.
- Native Windows saved-session retry: PASS, same integration scenario on this Windows x64 host, real owned API/PostgreSQL/WebSocket. Preferences and secure storage are in memory to preserve the user profile. SDK prerequisites use the normal pinned updater SDK and checksum-validated production DeepFilter cache. No Windows integration screenshot capability, installed-release/storage or media claim.
- macOS Keychain prompt/signed release and physical iOS: NOT_RUN; no relevant host/device available. OS storage requests are not forcibly cancelled.
- Contracts: full `python -m tools.ci.native.contracts` passes on Linux, including 1870 Python tests (28 declared platform skips). The first run correctly rejected a stale telemetry source hash; the source catalog was regenerated, with only two hashes changing. Nearest native selection/device/storage safety tests: 26 PASS.
- Merge gate: exact-head hosted CI must pass; see the pull request checks for its final result. No release, production deployment, physical audio or media claim.
- Wider Web runner: the auth-only invocation correctly rejected missing registry-selected coverage, then the all-feature Web run was started. Its first accessibility stage had 111 PASS and five module-loading/Pinia fixture failures; all five failed cases passed unchanged in a bounded rerun (12.8s). One later controls fixture timed out waiting for its diagnostics tab and passed unchanged in a focused rerun (2.3s). Original failure output is retained. This is not presented as a clean first-pass result; the remaining broader run and exact-head CI are independent merge gates.

Final Android capture hashes (runtime files remain under `.out/native-final/android/`, not committed):

- `startup-timeout.png`: `d174f9c9a2e54b21ee390c430c15967aa5e8b0efcb57351c4438d9ba2cba785e`
- `startup-recovered.png`: `3fd07370abbbffb27172c518e4acd9ffed8dfa1ceb41539f1ffc1bccc4a49bec`
- `startup-signed-out.png`: `c2f61b620474cfb5e6a4617e6fa3fed3ed6f036dbab4145f0222a54f7b567e1d`

Production restoration source SHA-256: `e5ce50beef52e8f608ba792b3e7bcf613c9d2b32614bb095a7d24239b2f39146`. The final native test releases the first response before retry; unit tests separately cover late responses after a successful retry.
