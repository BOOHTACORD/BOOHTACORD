# QA-12 / T-054 — live compatible rollback — 2026-10-18

**PASS for the signed API/web rollback and restoration on the prepared isolated
instance, two actual Web observers, real maintenance/admission enforcement and
persistent-data preservation.** This closes the live-rehearsal gap tracked by
#60. The older fake-Docker records remain historical evidence.

## Exact source and runtime

The accepted [native Linux run](https://github.com/Egkurilov/BOOHTACORD/actions/runs/39130446602/job/117684347504)
checks PR head `640073fd8826dd3bed013037093e13adb5385d66`; its actual synthetic
merge checkout is `e89396a771da78b1342c34230d7a12ef7b4b4e04`, tree
`92c65501a4f3b01ff6bc2d3ced3a3cd880c7d494`. Its parents are master
`7c0d15a597ee44fe9222f6b678540435459e2933` and that exact PR head.
The [machine receipt](qa12-live-compatible-rollback-2026-10-18.json) binds all
19 harness files and 35 active builder/dependency files by SHA-256.

- Current application source: `f8851896dba5b0b4002a3a9c53d327348aa133cc`,
  exactly tree-equivalent to that master. Actual successful CI run `39118858399`.
- Previous application source: `732bc4ae3b38e0865aa440df2378d803d2816e5e`,
  tree-equivalent to master `5eb564ff3f47962e09d9a05b17e2fe311bf2bb3b`.
  Actual successful CI run `39105987072`.
- Both have backend tree `f9fec33cfefd590e87a343fb630306bd73619641`, identical
  contracts, retained topology and all 52 migration inputs. Their Web sources
  differ. Original source IDs and gate job IDs are retained; images are never
  relabeled as a master squash SHA.
- Linux x86_64, kernel `6.17.0-1022-azure`, Docker `29.5.2`, Compose `5.1.4`,
  Python `3.12.15`; two independent Chromium `153.0.8010.12` contexts.
  PostgreSQL 17.6, LiveKit 1.13.7 and Caddy 2.10.0 actual image IDs are recorded.

The shipping trusted builder's explicit `--source` builds each clean retained
checkout. It archives, labels, smoke-tests and signs the actual selected source.
The active builder version is recorded separately; it now waits for PostgreSQL
TCP readiness before both real migration passes. The actual RNNoise compiler,
OCI/SBOM/provenance checks, image smokes and RSA signatures all run. A separate
QA public anchor was provisioned before artifacts; the private signing key was
deleted. No production release or production trust anchor is created.

## Prepared-instance boundary

The fixed shipping `voice-platform` project runs inside an owned initially empty
Docker daemon, with no host Docker socket or daemon TCP API. Only loopback 5443
is exposed externally. API, Web, PostgreSQL, proxy, retained runtime files and
the canonical signed rollback command are unchanged.

One explicit fixture dependency is an additional owned **SFU-only egress bridge**
for the retained `use_external_ip: true` configuration's real STUN discovery.
A real negative control failed without outbound access; the same LiveKit image
and configuration with owned egress answered authenticated RoomService RPC.
The bridge attaches before the SFU starts. Its management/metrics ports remain
unpublished; API/proxy networks and forwarding trust retain their configured
boundaries. The proxy uses the supported `.250` configuration input with its
matching `/32` trust pin, avoiding the observed first-dynamic-endpoint `.2`
collision. See the [runner conditions](../../tools/qa/compatible_rollback/README.md).

This is rollback acceptance on this prepared instance. Fresh production-network
provisioning, an actual production maintenance window, acoustic/media quality,
physical capture and capacity are outside this record. The disposable browsers
explicitly accept the owned certificate; canonical rollout curl trusts the owned
Caddy CA. Production browser trust-chain acceptance is not asserted.

## Required observations — all PASS

The owned fixture had two ordinary accounts plus an administrator, real TEXT/DM
messages and actual uploaded attachments before the window. Both observers were
authenticated and ready before the canonical command began at 13:16:49 UTC.
The sanitized artifact was retained at 13:20:09 UTC.

| Phase | Browsers authenticated | Actual banner | New leases | Login observations |
| --- | --- | --- | --- | --- |
| Baseline/current | 2/2 | Absent | 2 × 201, released with 204 | Initial UI logins 204 |
| Rollback maintenance | 2/2 | Visible in both | 2 × 503/MAINTENANCE | 2 × 503/MAINTENANCE |
| Previous release | 2/2 | Absent | 2 × 201, released with 204 | Original sessions valid |
| Restore maintenance | 2/2 | Visible in both | 2 × 503/MAINTENANCE | 2 × 503/MAINTENANCE |
| Restored/current | 2/2 | Absent | 2 × 201, released with 204 | Two fresh UI logins 204 |

The same canonical `tools.release.rollback.run --rehearse --observe-seconds 90`
performs both transitions. Both signed bundles and their expanded runtime are
verified. Read-only preflight leaves actual live image/schema/resource/content
observations unchanged. No fake Docker, routed browser responses, monkeypatches
or substituted transition code are used.

At baseline, previous and restored states, both actual configured API/Web refs
are `name@sha256`; each running image ID equals its verified OCI index. Image
revision labels and each browser's served release receipt match the expected
source head. The two original secure-cookie sessions remain valid on protected
API and identify their original accounts.

Across all three stable states, **four volume identities, the two canonical
network identities and the explicit SFU egress identity remain identical**.
Read-only fingerprints also match for nine committed product tables, actual
attachment files, persisted TLS keys/certificates, saved proxy config and actual
logical DDL. Both clients read the persisted TEXT/DM data and download the exact
attachment bytes on both releases. Operational session/read-cursor/lease/worker
state and WAL bytes naturally change; this is not a claim of identical physical
PostgreSQL files. No data copy, restore point or backup mechanism is introduced.

## Original-resolution visual inspection

All **ten original 1200×800 PNGs** were reviewed: each ordinary account in all
five phases. Both maintenance warnings are readable. The persisted conversation
and attachment remain visible; stable phases restore the normal banner-free
view. No login/error overlay covers the observed conversation.

A separate existing layout issue is visible in the four maintenance captures:
the banner shifts the full-height shell downward, putting the bottom account
footer and file-limit line outside this viewport. Stable captures show them
normally. This is recorded as an out-of-scope visual finding, not an overall
responsive-layout PASS. QA-12's banner/enforcement/data requirements pass.

Capture hashes and review observations are in the JSON. The source PNGs remain
in ignored `.out/issue60/native-accepted` and in the
[accepted artifact](https://github.com/Egkurilov/BOOHTACORD/actions/runs/39130446602/artifacts/12137129327)
with 30-day Actions retention. Generated media is not staged in Git.

## Verification and cleanup

- 34 focused tests PASS, including evidence incompleteness/drift, source-bound
  CI gates, ownership/isolation, cache binding, diagnostic privacy, exact source
  root/default behavior and bounded TCP readiness. Focused regressions were
  added before implementation.
- Three nearest Go maintenance/admission packages PASS. The full runtime above
  supplies real PostgreSQL/application integration, beyond these package tests.
- A separate owned PostgreSQL tmpfs control observed Unix readiness while TCP
  was unavailable. The corrected shipping helper waited 8.658 seconds and then
  an actual TCP SQL query succeeded. Earlier migration-smoke failures and one
  unsuccessful same-head retry are not accepted evidence; the final build runs
  both migration passes and all artifact checks successfully.
- Diagnostic fixture failures led to caller ownership/bytecode cleanup guards,
  valid Compose flags, proxy-address selection and explicit SFU egress. The final
  run's source hashes match the reviewed implementation; it completes with
  owned resources and temporary private inputs removed.
- The interrupted Mac x86 VM diagnostic is not a PASS. Its owned resources and
  forward were removed, VM stopped, and the separate existing 12-container
  environment and primary working-tree changes were preserved.

Public JSON excludes credentials, cookies, keys, raw logs, application account/
DM/session/lease identifiers and message/attachment contents. Captures contain
only owned synthetic UI. Artifact archive SHA-256 is
`7eadedf917b6d85ffa44eb4e9fedf6433646e1be15e3d92651e01892b53887ed`.

Spec traceability is checked against the committed 39-requirement index; the
approved Windows brief is unavailable on this Mac. Final exact-head CI and the
master merge are recorded in PR #379 and issue #60 after this evidence commit.
The overall release verdict and unrelated device/media gates are unchanged.
