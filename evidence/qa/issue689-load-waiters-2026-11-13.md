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
- Production event delivery, comparative capacity, fault recovery and a fresh
  exact-source load run remain separate and are not established by this test.
