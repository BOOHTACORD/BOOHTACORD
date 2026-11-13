# Issue #689: fault status, partial

The earlier short fault run could report PASS after the controller's two-second
auto-restore. This packet adds an authenticated status endpoint that checks the
owned resource: paused container state, bounded pressure file, or a live QA
database fault process holding the intended table lock. Restoration during an
inspection invalidates the result. The timer and ownership checks remain in force.

Twenty-five controller tests passed under Linux. The load runner now requires
confirmed fault state before and after each fault phase; a lost or unverified
fault fails the phase. Focused Go tests cover inactive and expired faults.
The database observation has not yet been exercised against the real disposable
stack. Full fault phases and capacity remain NOT_RUN.
