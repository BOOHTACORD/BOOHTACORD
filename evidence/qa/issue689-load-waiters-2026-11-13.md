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
- Production event delivery, comparative capacity and fault recovery remain
  separate and are not established by these tests.
