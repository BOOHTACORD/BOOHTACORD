# Issue 689: Flutter roster event parsing

- PASS: 26 Flutter realtime-scope tests, four focused tests after final formatting, and targeted analysis of changed files. Tests reject malformed roster events, retain the durable cursor for valid ephemeral snapshots, and validate duplicates, Unicode names and fixed unavailable codes. Registry policy and specification traceability passed.
- A broader analysis of the entire lifecycle directory also reported existing style diagnostics in unchanged `delivery.dart`; the targeted changed-file analysis passed after fixing new diagnostics. The full analyzer gate is not claimed here.
- NOT RUN: actual roster dispatch/store, server delivery and Android/iOS/desktop platform acceptance for this feature. The preliminary Android runtime smoke predates this change.
