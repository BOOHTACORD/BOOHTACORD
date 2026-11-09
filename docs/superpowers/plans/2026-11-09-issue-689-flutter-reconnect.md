# Issue 689: Flutter manual shared-socket retry

**Route:** `features/realtime/lifecycle` reconnect control.

- [x] Test manual reconnect of an active socket, preservation of the durable cursor and rejection of a late session check from an older attempt.
- [x] Close the prior socket before opening a replacement, fence older attempts and reuse the existing replay cursor.
- [x] Run focused realtime tests and analyzer. App roster binding and Android acceptance remain separate.
