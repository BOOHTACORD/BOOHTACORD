# Issue 689: roster revocation boundary

- RED: before the session-ordering change, `go test -count=1 -run
  TestRosterNotSentAfterSessionRevokedAtFinalBoundary
  ./internal/realtime/connect_session` reproduces a protected roster frame
  after a simulated session revocation between the final guard check and write.
  The test uses an in-process socket and a deterministic test double; it is not
  a PostgreSQL integration test and does not demonstrate external exploitation.
- PASS (session boundary only): after wiring a bounded PostgreSQL shared-lock
  guard around the roster frame write, the deterministic socket test passed.
  A disposable PostgreSQL 17.6 run of five focused packages passed 59 tests
  with zero skipped or failed, including real concurrent session revoke before
  and during delivery, blocked account, expired session and role change.
- The complete backend suite subsequently passed 1809 tests before additional
  end-to-end test additions; the final immutable build remains unverified.
- PASS (resource ordering, scoped): a later disposable PostgreSQL run covered
  88 tests without skips or failures. Concurrent tests observed PostgreSQL lock
  waits for actor-session revoke, participant-session revoke/expiry/idle,
  participant ban, voice-lease revoke and channel archive. A separate test
  reproduced and then rejected a lease-to-session binding change during lock
  acquisition. Empty LiveKit roster and bounded guard admission were tested.
- PASS (controlled end-to-end race): real PostgreSQL and WebSocket tests commit
  actor-session revoke, actor role or support-identity changes, participant
  session revoke/expiry, participant ban/rename, lease revoke or channel archive
  after the initial guard. Revoked actors get a policy close; changed rosters
  are suppressed and request refresh. The expanded focused run passed 100 tests
  with zero skips. These are synthetic participants
  and a controlled boundary, not physical media or a full load/security matrix.
- PASS (support identity ordering): a real PostgreSQL test observed an update
  wait for the in-flight delivery, then confirmed that a newly designated
  support identity cannot receive a roster. Missing identity fails closed.
  A separate concurrent test confirms that the ordinary support reply-cursor
  update remains possible during delivery with the narrower key-share lock.
- PASS WITH SCOPE: Linux Go 1.26.4 race detector and disposable PostgreSQL
  17.6 executed 101 tests across the delivery, roster and realtime packages;
  zero skipped or failed, with owned database cleanup. This remains dirty-source
  evidence and does not establish the full load/security matrix.
- BLOCKED: role/ACL policy changes, phantom topology, real slow readers, deadlock
  and pool-pressure load, plus final immutable build. The
  current permission registry defines
  channel create/delete permissions; it does not establish a distinct per-channel
  read ACL. Do not infer complete security acceptance from these scoped tests.
