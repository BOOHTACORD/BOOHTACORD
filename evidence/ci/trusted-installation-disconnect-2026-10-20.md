# SSH interruption — #395, 2026-10-20

PR #462 merged as `c47ae7fd0f225a14f5b6aa1dcef187df25ba00ea` after all 25
checks passed, including the protected GitHub Actions `ci-required` check.
The tested merge and resulting master tree both equal
`71299ea5de4fd1b047cc69e3339f82ba7c5f583e`.

The single subsequent actual [run 39351839757](https://github.com/Egkurilov/BOOHTACORD/actions/runs/39351839757),
job `118397600099`, finished **FAIL**. Artifact `12234415451` was downloaded and
checked against the authenticated size 878773 bytes and SHA-256
`49a8e81e264b0b025528f9eca5ac64f7a7d04f0f95860489c05e9a168a029c47`.
All 21 public files, 61 harness hashes and 56 builder hashes were verified.
The adjacent JSON records the original finite checkpoint, source metadata,
historical ACK validation and file digests. No raw private logs are published.

Both complete signed QA builds, initial install, upgrade and same-SHA retry
passed. All 16 real browser observations preserved the non-default MEMBER policy,
MEMBER-to-admin 403 and administrator-to-other-participants' DM history/file 404.
Four stable observations retained the original volume/network/content
fingerprints. Two original 1200x800 screenshots were reviewed: synthetic TEXT
and its 34-byte attachment remain visible, and the maintenance banner appears.
The existing banner layout still clips the lower footer/composer; no visual
baseline was changed. The other 14 captures were not visually reviewed.

The interruption checkpoint supplies the previously missing fact: client exit
143, phase `remote_install/interrupted`, host lock observed held and later idle
after 14.017798 seconds, **maintenance still active**. Recovery was correctly
refused. Exact signals delivered to remote descendants were not recorded; this
is not proof that closing SSH stopped Docker. Cleanup of owned QA resources
passed. Recovery retry, rollback/restore and remaining negatives stayed NOT_RUN.
The original browser RUNNING marker is incomplete historical output, not a live
job or a successful scenario. The strict whole-report validator rejects it.

The candidate adds a small invocation helper inside the already checksum-bound
current installer archive. It keeps the same canonical foreground command,
ignores inherited HUP and directs output to a private temporary file. The caller
continues to wait for the exact exit status, holds its driver directory until
completion, and removes the private log through its existing EXIT cleanup.
Signature, immutable source, expected-current CAS, host lock, live ACK freshness,
maintenance and recovery guards are unchanged.

A real owned process-group fixture first reproduced termination on channel
hangup/closed pipes and private output escaping to the channel (three red
assertions). The fixed helper passes the same fixture: lock retained across HUP,
driver directory retained while running, maintenance cleanup completes, private
log is 0600 and removed, no output on SSH pipes, exact exit 0/17 preserved.
This fixture is a nearest process regression, **not** a real SSH/Docker install.
35 focused installer/delivery/interruption tests passed in 2.083s. The mandatory
transfer fixture suite passed 28 tests in 2.308s; 7 historical/diagnostic/workflow
checks passed in 0.638s, including the exact manual guard command under `python -S`.
Bash syntax, actionlint and diff checks passed.
The final change keeps that existing manual workflow unchanged: the new
process regression runs through the already mandatory `transfer.test.sh` in
ordinary contracts/release-boundary CI. The two workflow checks were rerun
against the final unmodified workflow and passed. No routing rule was weakened;
the remaining change has server-only ownership under the existing map.

The actual corrected SSH scenario remains **NOT_RUN**. This is a production
driver change, so the strict retained-source currency guard now requires a fresh
qualified current master producer before another combined actual run. The guard
is retained; an old runtime is not relabelled or silently exempted. Independent
Pistol121 production review and the other epic acceptance gates remain separate.
No production SSH, local VM, Keychain operation or user checkout edit was used.
