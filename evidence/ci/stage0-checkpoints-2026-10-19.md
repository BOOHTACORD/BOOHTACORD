# #382: accepted code checkpoints, 2026-10-19 (Europe/Istanbul)

This is partial program evidence. GitHub events below occurred on 2026-10-18 UTC.
The parent epic remains open; missing repository/native/production/physical gates
are not inferred from these checks. The adjacent JSON binds each run/head, actual
Actions checkout, check IDs, verified master merge and native capture hashes.

| Checkpoint | Exact head | CI run | Result |
| --- | --- | --- | --- |
| #408 / #383 baseline | 3bf381314f97f0d5570a95ddc08b875917c84431 | 39163608414 | six checks PASS |
| #409 / #384 routing | c2d40c056a5423c1f438be0fe7cdf4077f6b0aca | 39163637266 | six checks PASS |
| #411 / #385 aggregate code | 9e611e26013971e5e875adfdcd02148d425308f0 | 39163657625 | six checks + ci-required PASS |

The three merge results were fetched and their ancestry/trees checked. After these merges,
master `ea1ca9027c4f4ecdb5bab16e1935e936cd01ac1d` had the exact accepted #411 tree.
Merged #407 Web diagnosis changes were retained; 12 focused Web tests passed.
All eight frozen baseline reports reproduce byte-for-byte at the recorded analysis
revision. The full sanitized offline inputs stay in the existing QA workspace;
the public cohort outputs are intentionally compact. The baseline runbook explains
how to select the frozen analysis source after future routing changes.
The v1 artifact-to-install figures are only head-coincident metadata correlations;
actual artifact-to-deployed-health timing is N/A without explicit producer lineage.
This clarification does not relabel the historical observation or its source.

## Native Windows fixture correction

The initial launcher assertion did not distinguish missing/not-yet-painted from
duplicate targets. The driver now observes frames in the same connected SFU
attempt, keeps duplicate/missing failures, and retains bounded failure diagnostics.
Four focused launcher/action tests, three fixture contracts and focused Dart
analysis passed. The original failure had no retained pixels; its exact observed
count/launcher is not reconstructed or labelled a confirmed flake.

Actual run 39163608414 / job 117782222274 passed four header/dock initial/traversed
cases using foreground-PID-guarded Win32 input and real API/PostgreSQL/LiveKit.
Artifact 12150680834 ZIP SHA256 and all eight image hashes were verified. All eight
1008×720 original-resolution captures were inspected: Close/Cancel/disabled Start
remain inside the viewport; advanced quality controls and fixed footer are visible;
after Escape the dialog is closed, focus returns, the listener stays connected and
the microphone remains muted. Start is disabled because no source was selected.
No physical audio, actual screen publication, updater N→N+1 journey or whole-app UI
acceptance is claimed by these fixture observations.

## Separate outstanding acceptance

The unchanged ordinary docs-only CI proof in closed-unmerged PR #413 completed in
94 seconds: contracts/selector/ci-required succeeded, four irrelevant components
were explicitly skipped. This single observation is not a general p95 or billing
claim. It also exposed GitHub's bare caller-name shape for skipped reusable jobs.
The master producer decoder follow-up and actual no-release/no-install acceptance
are tracked in [#416](https://github.com/BOOHTACORD/BOOHTACORD/pull/416) / #384; they are
not attested by this earlier checkpoint. Keep #384 open until that proof exists.

#385's code is merged, but required-status settings remain owner-managed and
unconfirmed at this checkpoint. No protection setting was changed. #386 is a
separate hardening task; its local checks are not part of these accepted PRs.
