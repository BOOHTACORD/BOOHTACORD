# Issue #689: Web malformed frames, partial

- Authenticated Web now disconnects and retries on malformed JSON or a binary
  application frame. It does not log the payload or silently keep the socket.
- Eighteen focused unit tests, Web typecheck and two Chromium tests against a
  real loopback WebSocket passed. The first browser test run failed because its
  synthetic ready frame encoded a 127-byte payload with an invalid short header;
  the fixture was corrected and both cases then passed.
- Flutter malformed frames, other envelope classes, full current-source
  real-stack, visual and production acceptance remain separate and NOT_RUN.
- Follow-up: non-object JSON also triggers recovery. Three new unit cases first
  reproduced the omission; 18 related Web tests, typecheck and three Chromium
  real-loopback cases passed. Flutter coverage is recorded separately.
- Follow-up: malformed frames and invalid new-event envelopes now clear the Web
  replay cursor before retry, including with batched delivery. Four focused
  regressions cover scheduled and manual retries; prior code reused the cursor.
  The current source still needs full-stack and visual acceptance.
