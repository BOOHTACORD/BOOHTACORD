# Backend same-source functional shadow harness — #401

Implementation base: master `a946915037619d9d46a229c2ed60ba51a70a1ba7`.
Original sequential coverage reference: `d552352482187b9822768161f8507d59cbf2e19e`.
This record qualifies the comparison harness, not an actual backend execution.

- Focused test-first checks: the new source-preflight test initially failed
  because stale PASS survived. Five workflow mutation cases initially failed
  because reordered invalidation/download/measurement, skipped checkout/SDK and
  extra commands were accepted. All were fixed before publication.
- Final nearest checks: 53 backend/workflow/action-pin unit tests PASS;
  delivery policy, component selection, reviewed action-pin validation
  (35 workflows, 2 local actions), actionlint for the new workflow and diff
  whitespace check PASS. No application assertion was retried.
- Initial local invocation errors are not tests: unittest discovery cannot
  traverse this namespace package; the explicit module list ran all focused
  tests. `tools.verify.action_pins` has no package entry point; its actual
  `tools.verify.action_pins.run` entry point was used. Merely importing policy
  modules was not counted as validation.
- Actual paired hosted run: **NOT_RUN**. It can be dispatched from master
  after merge. One complete pair can prove functional equivalence for its
  exact source/run/attempt; it cannot prove statistical speed or flake rates.
- Server producer, signing, native candidates, production installation,
  restricted operator identity and final owner GO are outside this change.
  Global cutover stays **NO-GO** and #401 remains open.

The normal backend workflow, its coverage, receipts, caches and release
authority are unchanged. New artifacts contain bounded public metadata only;
no raw test logs, database state, secrets or application captures are added.
