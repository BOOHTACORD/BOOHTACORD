# Combined CI acceptance, 20 October 2026

Reviewed code source: `79d1c36a1f7bc3053a01c88a32b7e78cc8b5a821`.
This records actual retained results and a partial cutover assessment. It does
not authorize production execution or replace pending native/physical gates.

## Required aggregate triage (#402)

[PR457](https://github.com/Egkurilov/BOOHTACORD/pull/457) merged normally under
the active strict `ci-required` ruleset. All 24 checks passed in
[run39329606270](https://github.com/Egkurilov/BOOHTACORD/actions/runs/39329606270).
The tested synthetic merge and final master have the identical Git tree
`13e2e0b528c731c9c2f91806e7b40c3fd3c1cf87`. The actual triage ZIP/digest and
source/run/attempt binding were verified independently. Three original red
aggregate metadata records were replayed with exact validator commands; their
historical cancellations and unknown root causes were preserved. See
`aggregate-triage-hosted-final-2026-10-20.json` and
`aggregate-triage-replay-2026-10-20.json`.

## Parallel runtime isolation (#398)

Two different PR lifecycle controllers actually overlapped for **206 seconds**:

| Workflow run | Job | Actual controller interval, UTC | Tested merge source |
| --- | --- | --- | --- |
| [39312750405](https://github.com/Egkurilov/BOOHTACORD/actions/runs/39312750405) | 118266382286 | 19:40:04–19:48:13 | b648e0029c6e396bda1cebbeaf6520f555424789 |
| [39311951333](https://github.com/Egkurilov/BOOHTACORD/actions/runs/39311951333) | 118263610836 | 19:34:18–19:43:30 | 2593a2f8d8314d6abf96495f98c696694d2e4c07 |

Both actual profiles passed with different Docker owner/port namespaces and
artifact identities, separate disposable hosted VMs/API/PostgreSQL stacks and
successful cleanup. The shipping fan-in independently verified both complete
ZIPs, all eight original reports and 268 capture records. Two original main-chat
captures were reviewed: selected channel, participant pane, composer and footer
were visible with synthetic fixtures. Ten tampered actual receipts were rejected.

The enclosing first PR's separate triage regression remained a failed PR; this
does not relabel that entire run green. No new runtime was dispatched to obtain
these results. The unchanged isolation/validation/risk-map inputs are recorded in
`parallel-actual-final-2026-10-20.json`. All three current automatic profiles and
their fan-in also passed in PR457. Physical/device and protected native release
acceptance remain separate and explicitly NOT_RUN in these runtime receipts.

## Compatible rollback and cancellation boundary

[Rollback39328262697](https://github.com/Egkurilov/BOOHTACORD/actions/runs/39328262697)
passed on harness `8add045642585429b1e573cea458fe5bcc72722b`, using real signed QA
images labelled by their original current `3d22e9007db090e6a2159841506e0e377ae8b0a4`
and previous `356d32c5ff6b661a747009ad93026c197bdd1b72` sources. Two browser
observers crossed current → maintenance → previous → maintenance → current.
Ten observations/captures, unchanged storage fingerprints, API admission/login,
exact image digests, all 25 harness/44 builder hashes and cleanup passed. The two
reviewed captures show the maintenance banner and restored authenticated chat.
No production host or signing credential was used. See
`compatible-rollback-final-2026-10-20.json`.

The actual later evidence-only master push did not cancel the earlier selected
native work: all nine predecessor jobs passed, and both unselected successor
workflows completed successfully. The predecessor qualified server bundle was
still waiting for genuine production review, not cancelled or implicitly
approved. This proves the different-SHA metadata cancellation boundary only;
it does not promise strict FIFO or successful publication/install. See
`master-race-final-2026-10-20.json`.

## Observation window

The bounded creation window 17:38:07–21:50:50 UTC on 19 October contains **78
completed workflows / 82 attempts**, including 13 failures, 26 cancellations and
nine intentionally skipped deploy notifications. All 177 listed records are
accounted for; pending and outside-cohort runs are explicitly excluded. Data and
reproduction inputs are `after-observation-2026-10-20.json` and its hash-bound
`after-observation-inputs-2026-10-20.json`.

| Cohort | Completed workflows | Successful wall p50 / p95 | Runner-minute p50 / p95 |
| --- | --- | --- | --- |
| PR CI | 33 | 997 / 3460 s (10 successes) | 92.4 / 171.5833 (32 complete intervals) |
| Native master | 15 | 1026 / 1341 s (7 successes) | 39.0167 / 48.4833 (14 complete intervals) |
| Server build | 14 | 878 / 1141 s (7 successes) | 32.8333 / 42.6833 (12 complete intervals) |

Historical PR successful wall p50/p95 were 1548/1601 s; occupancy p50/p95 were
65.8/74.2167 runner-minutes. Thus current median wall is lower, but p95 and
occupancy are higher. Selection/component/revision mixes differ, so no causal
speedup, cost saving or SLO claim follows. First-start delay is not pure runner
queue; failures/reruns do not prove flakes. Only one independently retained exact
healthy readback is joined here to master creation: 1107.942379 s, source356d32c5.
Other successful route-only notifications are not presented as healthy installs.

## Partial cutover and remaining boundaries

The fresh configuration-only rollback candidate `78d877ea6df0fb1eeb400ddd70bb0e4ac7306405`
passed all six checks; product/evidence were preserved and the clean original
branch restored. The active master ruleset was read back with exact GitHub Actions
app15368 `ci-required`, strict up-to-date checks, no bypass actors, deletion and
non-fast-forward restrictions. No settings were changed in this replay.

`cutover-partial-79d1c36a-2026-10-20.json` accepts five narrow criteria: historical
baseline, required-status settings, configuration rollback, isolated compatible
rollback and the already verified native SDK matrix. Retained execution sources
are unchanged and explicitly distinguished from the reviewed assessment source.
The decision remains **NO-GO**. In particular the mixed 78-run observation window
is not claimed to be 30 observations of one frozen final DAG.

Remaining open leaves are #386, #394, #395, #396, #397, #399 and #401 after the
scoped #398/#402 acceptances. Docker data-root/cleanup acceptance, the missing
restricted diagnostic SSH credential/account proof, remote failure/interruption
and same-SHA install cases, three application candidates, Windows installed-client
promotion, full cutover matrix/shadows and independent owner GO remain distinct
requirements. The macOS dry-run candidate39326402639 awaits Pistol121 review.
The read-only complete Actions secret-name inventory confirms the dedicated
diagnostic secret is absent; existing general deployment credentials were not
read, substituted or changed. See `operator-credential-readback-2026-10-20.json`.
