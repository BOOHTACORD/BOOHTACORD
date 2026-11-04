# Issue 648: Windows voice recovery

On 2026-11-04, a Windows release-mode test driver ran the Flutter application
against an isolated local API, PostgreSQL and LiveKit with a disposable account.
The client joined a voice channel as a listener. The owned LiveKit process was
then stopped for at least 130 seconds after the application entered recovery.
After LiveKit restarted, the client returned without user action to the same
channel, with a newly acquired lease. This was observed twice after the fix.

Before the fix, the same scenario entered recovery but failed to rejoin: the
server's VOLUNTARY_LEAVE notification for the lease released by the application
cancelled the recovery loop. The focused regression test reproduced that race;
additional tests cover a failed retry admission and administrator kick.

The candidate used a dedicated integration-test entrypoint and test namespace,
not an installed production package. The native build used version 1.0.49+85;
subsequent metadata prepares 1.0.50+86 for publication. The test did not verify
microphone capture, audibility, production, API-only outage, cancellation on a
real server, other platforms, or 5/15-minute outages. Those outcomes are NOT_RUN.
