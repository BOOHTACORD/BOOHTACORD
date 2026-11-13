# Issue #689 R2: Flutter connection deadline, partial

- Focused fake-clock tests cover a stalled open, retry, late socket closure,
  cancellation and the existing retry policy.
- An isolated loopback HTTP server accepted an upgrade without writing headers.
  After the 15-second deadline, it observed TCP EOF; the next attempt upgraded
  and reached protocol-ready. This test uses a real Dart HTTP client and socket.
- The complete realtime-scope and desktop recovery selection passed 45 tests.
- Android emulator, iOS, physical networks, blackhole/background conditions and
  production acceptance remain NOT_RUN. This record alone does not close R2.
