# Issue 689: maintenance propagation fixture

- Current comparative driver measures initial snapshots only. Add an opt-in,
  owned-fixture-only database change and measure when each socket receives the
  new maintenance state on both baseline and candidate transports.
- Tests must reject unowned or unauthenticated control requests, distinguish a
  change from an initial snapshot, and reject missing or duplicate observations.
  Restore the test state on cleanup and preserve the existing smoke profile.
- Report mutation-request-to-frame latency explicitly. This does not establish
  browser/Flutter UI application latency, physical media, final capacity,
  immutable-source comparability or full issue acceptance.
