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
phase duration, retains their error counts, and passes focused Go tests. A fresh
real-stack run of that change and the complete fault matrix remain NOT_RUN.
