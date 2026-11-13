# Issue 687: synthetic Web engine-switch endurance

On Windows 10.0.26300, Chromium ran a 1,800-second local synthetic microphone
call through the production Web microphone adapter and an isolated LiveKit
1.13.7 instance. The checked-in Web test at `4feaca072e693327b7e98dc614efd47a92398a3c`
alternated experimental RNNoise v0.2 and DeepFilterNet3 every 30 seconds:
60 switches completed, one publication was reported at each switch, and at
least one received measurement per interval contained nonzero finite audio. The test file
SHA-256 was `a4508681c1db11e9004dd84f8131a2055c698511812b2c60dcf2869f88de6d61`.

The browser used fake microphone audio and muted system output. The local
server used temporary credentials, was stopped after the run, and no PCM or
session credentials were retained. The 15-second setup check and a separate
65-second switch check passed first. A copy of the isolated Windows runner
exposed the sanitized Playwright result during the long run; afterward the
bounded checked-in runner also passed a 15-second smoke check. Temporary
RNNoise v0.2 browser assets were removed; they were not published.

This test checks periodic reception and switching in one synthetic call. It
does not establish uninterrupted per-engine 30-minute stability, mute/unmute,
reconnect, memory growth, real speech, audibility, native Windows behavior or
release acceptance. The model distribution rights remain unconfirmed. No
production release or deployment was performed.
