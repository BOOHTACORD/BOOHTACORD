# Issue #689: Windows promotion readback diagnosis, partial

- Run `43106285186` failed at deployment verification for deploy run
  `43104255315`. The retained deployment receipt reports PASS and includes
  `api`, `web` and `join-sound-processor` at the same source revision.
- The historical verifier required exactly `api` and `web`. Offline evaluation
  with the retained receipt and the corresponding workflow metadata reproduced
  its failure; removing only the third component in a diagnostic copy made the
  other deployment checks pass. This identifies a validator mismatch, not a
  WebSocket runtime failure or proof of current production state.
- The updated verifier accepts only the two explicitly supported component sets,
  requires matching revisions and validates the corresponding image digest set.
  Twenty-three promotion tests, twelve focused delivery/readback tests and the
  source check passed. Offline evaluation of the
  unmodified retained receipt now passes the archived deployment proof.
- Full promotion chain, current public catalog readback, signed binaries and
  installed runtime remain NOT_RUN. This record does not claim a new deployment.
