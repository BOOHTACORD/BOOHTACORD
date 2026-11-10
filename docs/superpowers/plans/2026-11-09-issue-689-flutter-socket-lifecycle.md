# Issue 689: Flutter authenticated socket ownership

**Route:** `features/realtime/lifecycle`, attempt notifications only.

- [x] Test one start/end callback per connection attempt, including failed handshakes, replacement, late callbacks and explicit close.
- [x] Expose optional lifecycle callbacks without changing existing reconnect, replay or session behavior.
- [x] Run focused Dart tests/analyzer. Shared feature wiring, emulator acceptance and load remain separate.
