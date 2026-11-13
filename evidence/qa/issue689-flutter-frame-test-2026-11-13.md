# Issue #689: Flutter malformed-frame regression test

Windows CI run 43347853196 failed `realtime_scope/events_test.dart`: it expected
the ready event to finish dispatching after a malformed frame had already
closed the socket. The same failure was reproduced locally with Flutter 3.47.7.
The pre-existing test now checks ready deduplication and a valid post-close event
independently. A controlled pending-recovery case verifies that a malformed
frame closes the connection and prevents the old ready continuation.

Thirteen focused tests passed locally, including the real-loopback malformed
frame and socket-generation cases. Full Windows CI on the new head and native
platform acceptance remain NOT_RUN.
