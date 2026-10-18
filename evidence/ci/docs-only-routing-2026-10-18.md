# Ordinary documentation-only CI routing proof

[Run 39163108152](https://github.com/Egkurilov/BOOHTACORD/actions/runs/39163108152),
[disposable PR #413](https://github.com/Egkurilov/BOOHTACORD/pull/413),
head `319d371b36f9ef4958a8f4307e86776fdf39af0c`, tested merge
`fef9d4b210eccf1460524fd555ca59ba2da39881`, base candidate
`8138e220b6e7c9e812f17edb1aad49ec0a88519d`.

Exactly one synthetic Markdown file differs from the prepared candidate. No
workflow, trigger, selector, validator, test or product code was changed for this
proof. The ordinary CI workflow executed its actual contracts job and aggregate:

| Job | Observed conclusion |
| --- | --- |
| changes | SUCCESS |
| contracts / contracts | SUCCESS |
| ci-required | SUCCESS |
| backend, frontend, Flutter, Windows | SKIPPED as explicitly irrelevant |

The aggregate's real log reports successful common selection, contracts and every
applicable gate. Complete raw run/job metadata was read via GitHub GET endpoints;
the adjacent JSON retains only scheduling fields. PR #413 was closed without merge.
The later parent candidate `9e611e26013971e5e875adfdcd02148d425308f0` adds merged
Web fixes; its workflow and CI routing sources are byte-identical to the proof.

One observation: creation to last active job completion **94 seconds**, active job
execution **1.5833 job-minutes** (selector, contracts, aggregate). Skipped jobs have
zero execution cost even though GitHub reports their completion one second before
their start. This is neither billing nor a p95/SLO, and does not compare different
risk cohorts. Product/native/media acceptance and the master producer/no-install
route are outside this scheduler proof; the full candidate gates remain mandatory.
Repository protection settings were not changed. The owner configures ci-required
personally; #385 remains open until actual settings/readback is confirmed.
