# Issue #689: load-driver fanout observation, partial

- CI run `43311698304`, faults profile: 686 fanout observations, one 503
  observation in the spike phase, p95 5.07 ms; the driver marked the criterion
  FAIL. That failed run remains a failure and does not establish its cause.
- The load driver had a single-consumer wake channel despite allowing concurrent
  waiters on a socket. A regression with two waiters and one delivered event
  reproduced a timeout on the original driver. This is a plausible source of
  false negatives, not proof of the specific CI failure.
- Broadcast wakeups and socket-generation checks release every relevant waiter
  and prevent an old waiter consuming a replacement socket's event. The focused
  package passed 20 iterations, all load packages passed their Go tests, and the
  final focused package passed the Linux race detector.
- Two isolated local fault profiles at `83cb107190c71b943d0ffdfd672a2b84f0caf4e6`
  failed: one stopped by the resource guard, the other observed five fanout
  errors and one success before failing the measured criterion. Both cleaned up
  owned resources. A driver 503 is an internal failure observation, not an HTTP
  response and not by itself proof of a lost server event.
- A third isolated fault profile at `500f48c5049efac55496bebbbfb1ff7f39e2f8e9`
  failed with `guard_resource_stop`; cleanup passed. Its bounded diagnostic
  captured one WebSocket close code 1013 and a one-second session revalidation.
  This is consistent with fail-closed session checking during the injected DB
  lock, but 1013 has another server-side cause and neither the precise close
  source nor the guard's reason was recorded. No fanout measurement occurred.
  Reports are retained outside the repository under the local QA artifacts.
- At `cb44a4b3ff26393746b6ce65be282c558db4e4dd`, the next isolated run again
  stopped on the guard, categorized only as a non-200 response; one 1013 close
  was observed and no fanout sample was recorded. At `bd71bfee6d1077a0ad7cbf806c2e1c18683a465a`,
  the following run stopped in the ramp fault operation with one successful
  fanout. Its later `unavailable` monitor category may have been caused by
  owner cancellation, so it is not evidence of an independent guard failure.
  Both runs failed and cleaned up owned resources. The reporting path now
  ignores cancellation and preserves earlier stop reasons; these changes need
  another source-bound profile. Linux race coverage for this latest reporting
  edit is NOT_RUN because the available WSL environment has no C compiler.
- The isolated run at `16db13d4d19962f0153b12668d60be4e7c24222c` failed with
  the first stop reason `guard_resource_stop` and the fixed category
  `resource_snapshot`; it saw one 1013 close and one successful fanout. The
  steady phase was canceled after the guard stop; cleanup passed. The category
  identifies the guard's resource-sampling step, not its underlying cause.
- At `7b8dd0e25cd8862c8789e9760f17821994fbf113`, the next run failed during
  fault setup with a resource threshold result; ramp and steady reported zero
  workload requests, and cleanup passed. Its recorded samples do not identify
  which threshold was crossed. This does not prove a server capacity failure.
- A separate synthetic concurrency regression exposed overlapping reads of the
  guard's previous CPU sample and, on this host, a zero time interval causing
  division by zero. Reads are now serialized and nonpositive intervals fail
  closed. This establishes a controller defect, not that it caused any earlier
  profile failure; a source-bound retest is still required.
- Production event delivery, comparative capacity and fault recovery remain
  separate and are not established by these tests.
