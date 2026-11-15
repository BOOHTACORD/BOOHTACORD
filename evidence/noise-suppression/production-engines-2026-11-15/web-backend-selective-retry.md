# Web/backend receipt collection on selective retry

Scope: CI receipt collectors and their mandatory test binding. No application,
DSP or server build was run locally; audio/load thresholds remain unchanged.

PR #804 run 43731170030 attempt 1 failed two component jobs: load/faults
recorded one fanout HTTP 503 (P95 3.9492 ms), and Firefox receiver mute measured
peaks [0.000122, 0.000031, 0] against 0.0001. The underlying cause of those
intermittent measurements is not established. Other four load profiles and
four Firefox cases passed. One bounded failed-jobs-only retry was requested;
this record does not declare that retry successful.

Web/backend aggregators also downloaded only the latest global attempt,
which cannot retain successful peers during a partial retry. Extend the same
source/run-scoped separate-archive selection used for Flutter/actual to these
two families. Every current prerequisite must still succeed. Each original
execution, complete operation coverage, Web plan digest, namespace, source
and run remain mandatory; newest failed evidence cannot be replaced by an
older success. Legacy flat verification remains current-attempt strict.

PASS: 52 focused collector, validator and workflow tests, including negative
status/source/run/operation/attempt/parent-result cases. The new profile-parts
regression failed before implementation. History/inheritance regressions are
now explicitly invoked by the mandatory contracts workflow.

PASS: replay of 9 authentic artifact ZIPs from source
dc7bb9412dc52cb35a37ef6493fecedab72f14dc / run 43719912933, all sizes/digests
checked. Three backend and six Web attempt-1 receipts validate under the
same run's attempt-2 aggregation, whose corresponding parent jobs succeeded.
No receipt bytes or GitHub check states were rewritten. Mixed-attempt cases
are covered by the focused tests; this replay does not claim a new load or
acoustic measurement.
