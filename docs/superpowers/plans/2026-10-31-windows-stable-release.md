# Windows 1.0.48 Release Plan

> **For agentic workers:** Execute this plan sequentially using the existing native release and catalog workflows.

**Goal:** Publish current master as Windows 1.0.48 (84), then make the stable catalog offer it to the installed 1.0.47 (82) client.

**Architecture:** Preserve Flutter application behavior and package/signing identities. Advance the shared native version metadata, publish immutable exact-source assets, and promote only Windows/direct/stable/x64 through the existing guarded workflow.

**Tech Stack:** Flutter, Python release contracts, GitHub Actions, Velopack, public update catalog.

## Version preparation

- [x] Baseline installed version 1.0.47 (82), release order 61, against public catalog revision 29 targeting 1.0.38 (71), order 52.
- [x] Synchronize clean implementation branch with master 5327a51a65139b9f3ea5df548d88ca75c2f0705d.
- [ ] Change `clients/flutter/pubspec.yaml` to 1.0.48+84; match native entries in `contracts/client-build.json` at order 63; match development display defaults in `clients/flutter/lib/src/app_version.dart`. Preserve web identity and all selectors.
- [ ] Validate identity, native release contracts and publisher tests; run `tools/verify/contracts/verify-contracts.ps1`. Existing source tests that clear Windows PATH remain locally blocked until Linux CI verifies them.
- [ ] Review exact diff and file sizes; commit explicit files, open PR, require passing current-head CI and merge to master.

## Immutable Windows release

- [ ] Prepare `windows-v1.0.48` only at the reviewed master-reachable version commit using `tools.release.native_contract.tags`.
- [ ] Dispatch `.github/workflows/windows-release.yaml` with `dry_run=false` from that exact tag. Require successful tests, analysis, build, package and asset verification before publisher runs.
- [ ] Verify published tag, source, version/build/order, complete asset set, hashes and measured signing status. Record evidence under `evidence/release/`.

## Stable catalog publication

- [ ] Dispatch `.github/workflows/promote-windows-client-update.yaml` for `windows-v1.0.48` at the fresh expected catalog revision.
- [ ] Inspect the generated exact-source candidate and CI; attach its PR, require protected checks, then merge it. Preserve all other selectors.
- [ ] Wait for successful production deployment and source-bound readback; query the public Windows selector and verify version 1.0.48 (84), order 63.
- [ ] In the running installed Windows client, manually check updates and inspect the visible offer. Preserve the active call and session; do not force restart or installation.

## Completion boundary

Compilation alone is insufficient. Complete when immutable assets are published and the live stable endpoint plus old installed client expose the release. Report any skipped device/media or installation acceptance explicitly.
