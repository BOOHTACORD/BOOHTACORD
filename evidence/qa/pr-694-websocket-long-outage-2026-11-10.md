# PR 694: long outage after the WebSocket migration

The original PR changed the now-removed roster SSE retry loop. The migrated
roster uses the shared WebSocket controller, which keeps a single retry timer
and continues retrying after the former SSE budget would have been exhausted.
This PR retains the historical SSE evidence but does not restore that code.

The replacement Flutter regression uses virtual time to exercise nine failed
opens followed by a successful protocol-ready event, including the single
timer invariant. Seven focused realtime/roster tests and 20 LiveKit verifier
tests passed locally; 20 local feature policy tests also passed.

These tests do not establish a real-device outage, an authorized nonempty
roster after network recovery, production behavior or media quality.
