# Issue 648: Android recovery after session revocation

2026-11-09; integrated candidate `be97f71727a6d263390ebe13c30ad93228c71760`;
Android 15 emulator, local API/PostgreSQL/LiveKit and a synthetic account. The
Android integration driver joined a voice channel. The owner-checked controller
stopped SFU; after Android entered reconnecting with recovery active, a separate
browser session for the same synthetic account called the normal
`/me/sessions/revoke-others` endpoint, returning HTTP 204. The SFU was then
restarted. Android reported no active recovery and no selected voice channel,
and both remained absent for 90 one-second observations. The Android driver,
revocation controller and browser control exited 0.

The original-resolution screenshot (1080 x 2400, SHA-256
`1a81e104b2025fccde899f77d9a57c6a4bab423350d7c3bde6f30f8d99ae84d1`)
was inspected and shows the signed-out login screen. The observation starts
when cancellation is detected; the SFU restart was initiated immediately
after the revocation marker, not independently timed relative to every sample.
The first browser attempt incorrectly expected HTTP 200 from successful login;
actual 204 was accepted in a second attempt, which revoked the Android and any
other prior synthetic sessions. It did not require restarting the test stack.

Scripts are retained alongside this report. Temporary emulator reverse
mappings and test app were removed; the owned stack stopped. This scoped result
is not proof of physical devices, ban/kick/handoff cases, production or the
full feature gate. No server deployment occurred.
