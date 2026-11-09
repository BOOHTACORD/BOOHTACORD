# Issue 648: observed transfer flag and active-device handoff

2026-11-09; integrated candidate `be97f71727a6d263390ebe13c30ad93228c71760`;
local owned API/PostgreSQL/LiveKit, synthetic account, Android 15 emulator and
headless Chromium. No production service or account was involved.

In a repeat of the recovery race, the browser's successful lease request was
observed with `transfer=false`. It joined after SFU restart, stayed connected
through nine ten-second checks, and Android cancelled recovery and stayed out
for 90 one-second samples; both processes exited 0. The test delayed the
browser credential request until the restarted SFU TCP port listened. This
confirms this run did not exercise forced transfer during recovery. It does
not retroactively determine the request flag in earlier runs.

A second, separate Web-only check started two browser sessions of the same
synthetic account. The first joined an active voice room; the second joined
through the normal Web UI. The observed accepted lease request contained
`transfer=true`; the first browser's voice status ceased to be connected and
the second remained connected through three ten-second checks. The Web control
exited 0. This confirms the forced-transfer path for an active first client,
not a forced transfer while that client is recovering.

Scripts for both checks are retained here. The isolated stack was stopped,
emulator reverse mappings removed and the test package was absent afterward.
No screenshots, physical audio, forced-transfer-during-recovery acceptance,
production acceptance or server deployment are claimed.
