# Issue #689 R2: Flutter session revalidation, partial

- A fake-clock regression reproduced a stalled session check preventing retry.
  Manual retry also reproduced a still-active old session check.
- A ten-second deadline releases the retry path and aborts its HTTP request;
  explicit close and manual retry cancel the old request. Late 401 results are
  ignored after cancellation. An actual loopback HTTP request observed TCP EOF
  when its owner was closed; the late-401 regression retains a test cookie.
- Realtime, session lifecycle and desktop recovery suites passed 59 tests;
  the additional late-401 test passed separately.
- Native device, background/network changes, existing in-flight storage writes
  and production acceptance remain separate and are not established here.
