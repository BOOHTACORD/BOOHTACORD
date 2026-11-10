# Issue 689 shared maintenance observer wiring

**Goal:** Use one process-scoped maintenance observer for public and capability-enabled authenticated sockets.

**Route:** `app/public_realtime`, `app/chat_routes`, and the exact runtime composition edges.

- [x] Test both socket types share generation and receive one state change.
- [x] Confirm RED; expose the owned observer to the authenticated route without changing legacy clients.
- [x] Run focused race and contract tests; record remaining real-stack, client and load gates.
