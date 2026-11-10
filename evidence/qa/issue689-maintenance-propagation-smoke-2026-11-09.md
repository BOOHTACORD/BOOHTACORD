# Issue 689: maintenance propagation fixture smoke

- PASS (tool smoke): the opt-in owned fixture changed the disposable database's
  maintenance flag and recorded a valid activation frame for every client on
  both implementations. One-account reports:
  `.out/roster-matrix/candidate-1-0-change-20261109T055629Z-f6e20150/` and
  `.out/roster-matrix/baseline-1-0-change-20261109T055753Z-a9854199/`.
- SMOKE_PASS, 100 synthetic authenticated connections and 20 empty voice
  rooms: `.out/roster-matrix/candidate-100-20-change-20261109T055957Z-245a3941/`
  and `.out/roster-matrix/baseline-100-20-change-20261109T060107Z-7c14cd9b/`.
  Each recorded 100 activation frames and removed its owned resources. The
  request-to-frame p95 was 2581 ms candidate and 4771 ms baseline; each value
  describes recipients of one state change, not independent repetitions.
- Initial maintenance p95 was 27.7 ms candidate versus 4.8 ms baseline; initial
  roster p95 31.2 versus 25.5 ms. Final DB acquire counters were 3242 and 2292
  respectively. These preliminary differences need investigation and repeats.
- The candidate and driver were dirty, although the candidate worktree
  fingerprint matched before/after
  `03853e08f18c6f6037d9618ef578b7ae845714c5ff1b502bc154a3ec74f421ba`.
  The timer includes the guarded mutation request; it measures transport-frame
  arrival, not Web/Flutter state application or physical media. Immutable
  paired matrix, repeated changes, restart storms, failure and capacity gates
  remain NOT_RUN.
