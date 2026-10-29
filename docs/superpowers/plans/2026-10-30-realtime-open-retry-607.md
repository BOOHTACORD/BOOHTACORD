# Socket-open retry preservation — #607

Execute inline; route small_direct, realtime/lifecycle/connect.
Preserve socket ownership, session/server/installation generation checks,
durable delivery, manual retry, bounded jitter/backoff and protocol-ready reset.

1. Retain the native RED: an owned API future fails socket-open; connecting
   becomes false but retry remains null. Timer-driven subsequent failures must
   also schedule one next retry. Closed/stale scopes must schedule nothing.
2. Release the current connecting guard before scheduling failure recovery.
   Avoid effects for superseded admissions. Keep other lifecycle behavior intact.
3. Test a real disposable loopback HTTP503 handshake followed by WebSocket
   upgrade/connection.ready; require automatic recovery without manual input.
   Run all nearest realtime_scope tests and native analysis. No production fault,
   network/router change or socket/payload logging is needed.
4. Record source, commands, platform, obligation and results; delegate PR/CI,
   standard merge/delivery and trusted candidate handling to release_closure.
   Keep aggregate physical/native/media gates and43 consolidations separate.

Stop: focused RED/GREEN and real local WebSocket recovery verified, retained
tests/source in master with final CI and delivery evidence. Production recovering
banners are observations; their exact cause is not established by this test.
