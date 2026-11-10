# Issue 689: unchanged roster after transient delivery failure

- RED: a recipient whose preparation check failed once received unavailable but
  no subsequent roster. The coordinator performed 17 unchanged reads without
  another recipient check. A separate real-WebSocket test reproduced the same
  stuck state when the final delivery guard failed once: 34 unchanged reads and
  one attempted delivery over one second.
- RED: Web and Flutter both rejected an equal-revision snapshot after an
  unavailable event, leaving the UI stale even when the backend recovered.
- The coordinator now marks the affected subscription for redelivery on its
  next normal reconciliation; it does not schedule immediate work, and other
  subscribers do not get an unchanged duplicate. The preparation and final
  delivery guards use this bounded recovery path. Both clients accept the same
  revision only while stale/unavailable; older revisions remain rejected.
- PASS: focused backend WebSocket/coordinator/preparation tests under Linux Go
  1.26.4 race detector, 10 repetitions for the three owning packages. A separate
  PostgreSQL 17.6 owned fixture ran 105 race-detected tests and subtests, zero
  failures and zero skips, and verified fixture cleanup. This includes a
  synthetic 100-waiter admission/recovery check; it is not a network slow-reader
  or capacity test.
- PASS: five focused Web roster tests and eight Flutter roster-state tests; the
  added Web and Flutter cases also passed after the stale retention timer
  expired. Flutter used the pinned Windows SDK; its SDK printed an existing
  Zone.Identifier warning, with exit status zero for the tests.
- Source was an uncommitted worktree based on 72928320d. The preceding 20
  preliminary matrix cells used the previous dirty source and empty rooms;
  they do not validate this fix or establish capacity. Real-stack browser and
  Android recovery, immutable build, slow network readers, complete platform
  acceptance and final load/release gates remain NOT_RUN.
- A third RED WebSocket test reproduced the failure when the intermediate
  asynchronous authorization check fails. An initial fix also revealed that
  clearing `initialized` invalidated an otherwise current snapshot, causing an
  immediate refresh. The final design tracks retry intent separately, leaving
  the current snapshot valid; the affected subscriber is retried on the next
  ordinary invalidation. The new test verifies there is no immediate read and
  that a subsequent invalidation restores delivery. All three owning packages
  passed ten repeated runs under the race detector after the correction.
- After the asynchronous-check correction, the owned PostgreSQL 17.6 fixture
  was rerun with Go race detection: 106 tests/subtests passed, no failures or
  skips; the fixture was removed. Real slow-reader and device gates remain open.
