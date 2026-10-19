# Master source cancellation boundary (#395 / #401)

The old ref-wide master concurrency could cancel a runtime source when its next
push only changed evidence. The new selector would then skip native/bundle work,
leaving the earlier required check or release with no replacement. Native run
39317404355 contains an actual cancelled GUI child and two failed required
aggregates; the following 39319882366 completed all nine jobs. These historical
runs prove the old failure boundary, not hosted acceptance of the new policy.

Four focused test methods first produced twelve failing assertions. With
source-scoped root groups, the same-source cancellation policy and mandatory
non-cancellable qualified-bundle lock, all 37 nearest tests passed (3.788 s).
The full delivery policy and pinned Actionlint 1.7.11 passed. See the companion
JSON for exact job identities and timestamps. New hosted cancellation/race
acceptance remains pending; #395 and #401 are not closed by this record.

Ruleset administration is separately captured in
`required-status-admin-readback-2026-10-19.json`: owner-authorized active master
rule, strict GitHub Actions ci-required, deletion/force-push denial, no bypass.
It does not assert that production independent-review settings are configured.
