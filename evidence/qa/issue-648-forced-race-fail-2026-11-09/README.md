# Issue 648: forced-transfer recovery race, initial failure

2026-11-09, integrated candidate `be97f71727a6d263390ebe13c30ad93228c71760`.
Android 15 emulator and Chromium used separate sessions of one synthetic account
on isolated API/PostgreSQL/LiveKit. A temporary Caddy rule returned HTTP 503
for DELETE voice lease requests, confirmed by a dummy request. This fault
injection is deliberately non-production. SFU was stopped; while Android was
recovering, Chromium used the real UI and acquired a lease with `transfer=true`.
The test held the browser credential request until restarted SFU TCP 4981
listened; Chromium connected. Android failed its combined assertion (recovery
inactive AND channel null) after 120 one-second samples. The browser check
then timed out waiting for the Android success marker. The combined failure
alone does not prove retry remained active: later focused unit reproduction
showed accepted transfer cancelled recovery but left the old channel selected.

Scripts and proxy wrapper are preserved here. A first wrapper invocation
failed with a Python syntax error before starting any stack; the corrected
wrapper ran the experiment. Owned services and reverse mappings were removed,
and the test app was absent. This records FAIL under an injected release
failure, not a production reproduction or a physical-device claim.
