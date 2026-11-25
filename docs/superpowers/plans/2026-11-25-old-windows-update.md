# Legacy Windows update acceptance plan

**Goal:** Finish #249 using the original Windows 1.0.32/46 and the current
approved stable release, without downgrading the owner's installed application.

**Architecture:** An external UI Automation driver observes original published
EXEs on a disposable hosted Windows runner. Production requests are read-only.
Download identities and every extracted baseline file are verified. The old
client's supported manual download/install path is preserved.

**Tech Stack:** Python unittest, Windows UI Automation/C#, PowerShell, Actions.

## Operating brief

- Mode: split_first; implementation leaf `tools/qa/legacy_windows_update`.
- Base: `2f301dda539a9f38d5c11b477a4a946130b7e20e`.
- Native edge: mandatory step before existing Windows GUI/SFU acceptance.
- Ratchets: target100/hard120 lines; <=8 production files and8 direct tests.
- Preserve existing GUI/recovery gates, publisher trust, catalog ordering and ACL.
- Old target1.0.38 is historical; accept the approved current stable, no downgrade.
- Stop: genuine old/new UI acceptance, verified public readback, checks/CI green,
  merge and truthful ticket update. An unavailable UI result cannot pass.

## Checklist

- [x] Add focused negative tests for policy/asset/result and hosted-only boundaries;
  run the three named unittest modules listed in the leaf README; require RED.
- [x] Implement bounded public downloads and source/content verification; reuse
  `desktop_updates.windows_tools.download_verified` and `extract_verified`.
- [x] Implement external PID-scoped UIA observation/capture of the original old
  EXE and the installed current EXE, with exact version/offer assertions.
- [x] Integrate the acceptance as an unconditional Windows GUI job step, retaining
  bounded synthetic captures and a fail-closed result; add workflow-negative tests.
- [ ] Run focused unit/contract checks, reviewed commit preflight and PR CI.
- [ ] Inspect actual runner images at source resolution; resolve only observed
  failures. Record distinctions between endpoint, executable and UI proof.
- [ ] Merge only after checks pass; update #249 with source, CI and actual limits.
