# Issue #689: Web malformed frames, partial

- Authenticated Web now disconnects and retries on malformed JSON or a binary
  application frame. It does not log the payload or silently keep the socket.
- Eighteen focused unit tests, Web typecheck and two Chromium tests against a
  real loopback WebSocket passed. The first browser test run failed because its
  synthetic ready frame encoded a 127-byte payload with an invalid short header;
  the fixture was corrected and both cases then passed.
- Flutter malformed frames, other envelope classes, full current-source
  real-stack, visual and production acceptance remain separate and NOT_RUN.
