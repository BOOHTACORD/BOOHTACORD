# Issue #689: fault status, partial

The earlier short fault run could report PASS after the controller's two-second
auto-restore. This packet adds an authenticated status endpoint that checks the
owned resource: paused container state, bounded pressure file, or a live QA
database fault process holding the intended table lock. Restoration during an
inspection invalidates the result. The timer and ownership checks remain in force.

Twenty-five controller tests passed under Linux. The load runner now requires
confirmed fault state before and after each fault phase; a lost or unverified
fault fails the phase. Focused Go tests cover inactive and expired faults.
On the disposable stack at local commit 37c2c953, the database lock was seen
initially, but the 20-second, one-account profile failed `fault_lost`: a blocked
request outlasted the two-second fault. Cleanup passed. This is not capacity or
successful fault acceptance. The subsequent change bounds requests within fault
phase duration, retains their error counts, and passes focused Go tests.

At local commit 78931e5c, the same short run passed its database fault phase,
then failed in the next phase with five fanout errors after a 1013 socket close.
Cleanup passed. The harness now detects a failed current socket and explicitly
reconnects it during a fault profile, recording the reconnect and preserving the
original close/error observations. Focused tests pass; this latest recovery
change has not yet been validated against the real disposable stack.

The controller now accepts a phase-sized duration with a three-second margin,
bounded to 30 seconds; longer phases fail before injecting a fault. Database
statement and controller auto-restore timeouts both remain bounded. A timer from
an earlier generation cannot restore a later fault. Controller and Go tests pass;
this duration protocol still needs real-stack and safety-threshold validation.
