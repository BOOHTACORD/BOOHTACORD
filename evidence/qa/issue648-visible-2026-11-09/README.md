# Issue 648: visible recovery state on a real Android stack

Source: master 8306413a84c224a712509d7a059916c95b00bd3c plus this branch's Flutter admission change. Environment: Android 15 Pixel emulator and an isolated local API, PostgreSQL and LiveKit, with a disposable account; not production.

Baseline: after a stable listener connection, a LiveKit-only outage caused a failed retry to publish VoicePhase.error while automatic recovery remained active. The UI showed "Голос не подключён" and removed the channel/leave control. The regression test failed against baseline (expected reconnecting, got error). Baseline screenshot SHA-256: 5af081e21397e3eea8cc76158c287aa2323f05fb6e591bb63fd64fe4b746d073.

Fix: a transient failure during an active retry retains the channel and the reconnecting state. Terminal authentication/access failures and server revocation retain the existing failure behavior. No media or server policy was changed.

On the emulator after the change, LiveKit was stopped for 45 seconds after a ten-second stable baseline. A failed retry kept the same channel and displayed "Голос восстанавливается" and the leave button; after LiveKit restarted the client returned to the same channel. The native screenshot was inspected at 1080 x 2400; SHA-256: 0d61af33a55c8eb76dbc5a624c3da537849502b836c7fe71e20e7ce7712f942b. The actual test source is recovery.android.dart.txt.

A separate real-stack run stopped LiveKit, waited for a failed retry, and explicitly left. After restart, the client did not rejoin during 90 seconds of observation. Its source is leave.android.dart.txt. 29 adjacent Flutter tests passed, including cancellation, logout and terminal status handling; focused Dart analysis and client parity validation passed.

Correction to earlier issue-648-sfu-only evidence: its observation of reconnecting about two seconds before container FinishedAt was compared with completion of Docker stop, not with the start of the stop operation. It does not establish that reconnection began before shutdown was initiated. The ten-second baseline in the later run above is separate evidence.

Limits: emulator runtime is not a physical Android device; microphone/speaker audibility, Windows recovery, production deployment and the complete cross-platform acceptance matrix are not established by these runs. This does not close #648.

Windows attempt: built the candidate debug client and used an isolated in-memory preferences and secure-storage backend with the same owned API/SFU stack. Two attempts failed before outage injection: initial listener admission returned MediaConnectException after approximately 22 seconds, so the actual Windows recovery behavior remains NOT RUN. The cause of the media connection failure has not been established; it must not be attributed to production or to the candidate change. Preferences of the installed client were verified unchanged during both runs. The Windows test source is recovery.windows.dart.txt.

The full feature check was invoked against the candidate. Its voice-only selection initially rejected additional affected feature groups; rerunning with auth, connection_status, screen and voice selected began the full suite. The Web accessibility stage failed 5 of 114 cases (including dynamic-import failures); the mini-player stage failed one 30-second timeout out of 21. These are failures of the broad check, not proof of this change's correctness or root cause. Further stages are reported separately when complete.
