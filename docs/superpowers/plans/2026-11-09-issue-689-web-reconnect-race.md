# Issue 689 Web reconnect race

**Goal:** Prevent a delayed session check from an old socket failure from opening or closing a newer socket.

**Route:** `clients/web/src/realtime` connection owner and nearest typed tests.

- [x] Reproduce late successful and failed session checks during manual reconnect.
- [x] Confirm RED; bind the asynchronous decision to the originating socket attempt and keep a single open socket.
- [x] Run focused reconnect tests and Web build; real network fault acceptance remains separate.
