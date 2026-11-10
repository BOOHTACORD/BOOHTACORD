# Issue 689: Web roster on the authenticated socket

**Route:** workspace realtime dispatch and roster composition.

- [x] Test capability negotiation, delivery without unrelated REST refresh and socket lifecycle/retry behavior.
- [x] Wire roster state into the authenticated socket and workspace; retire the workspace-owned SSE subscription while preserving reconnect status.
- [x] Run focused and broad Web tests/build.
- [ ] Run the registered real-stack browser scenario with source-resolution screenshot review. Native client migration and load remain separate.
