# BOOHTACORD repository reorganization implementation plan

**Goal:** Implement the owner's complete 2026-09-28 reorganization proposal,
preserving behavior and applying the already accepted GitHub migration.

**Architecture:** One Go monolith, Vue client and one Flutter project. Trusted
CI builds immutable artifacts; installation verifies and installs those exact
artifacts. Native composition and state owners are extracted behind existing
interfaces before callers change. No product or ACL redesign.

**Tech stack:** Go 1.26.4, Node 24.18.0, Flutter 3.47.5/Dart 3.13.4,
PostgreSQL 17, LiveKit, Docker Compose, GitHub Actions.

## Input and baseline

- Requested document: BOOHTACORD_REORGANIZATION_PLAN_2026-09-28.md.
- Input SHA-256: d0053e94747b08eec3dcf6a1ef1958a252cd69aa284a55bb686543b7a1f7df2f.
- BASE_SHA: 8b7f1ddc196c6ead42f45a4b4fe06ac896c0f9a5.
- Branch: codex/repository-reorganization.
- Route class: split_first; each row below is a separate bounded packet.
- Native gates and real media acceptance remain separate.
- GitVerse production-authority statements are superseded by ADR-011.
- Android/Windows artifact retention already exists; preserve and extend it.
- Existing OTel infrastructure is preserved, without introducing new collection.

## Ordered packets

| Packet | Exact ownership | Validation / stop condition |
| --- | --- | --- |
| PR-00 | Root instructions, native manifests, evidence/reorganization | Pinned baseline, full native test results, measured source archive, tool availability |
| PR-01 | frontend/Dockerfile, tools/build/web | public copied, PNG signature/content type checked from built image, Node version agrees |
| PR-02 | tools/toolchains.json, tools/ci, Taskfile.yml | Shared test/build commands, version mismatch negatives, mandatory PostgreSQL major/no-skip gates |
| PR-03 | contracts/release-manifest.schema.json, tools/release/bundle, tools/build/server | OCI digests/SBOM/provenance and source-bound checks verified; built-image smoke |
| PR-04 | tools/release/install, tools/release/rollback | Install does not build; checksum/signature/compatibility/space/digest negatives and staging receipt |
| PR-05 | .github/workflows, tools/ci/select_changes | Component selection, unknown-path full checks, one non-cancellable install lock; same-SHA receipts |
| PR-06 | tools/build/native, release workflows, vendor records | Retained artifacts, checksum/version/signing metadata, no binaries in Git |
| PR-07 | frontend → clients/web, desktop → clients/flutter, exact callers | Mechanical move, unchanged package/app identities and local overrides; native suites |
| PR-08 | scripts → tools/ci,build,release,verify,qa,ops | Real ownership moves, temporary wrappers, negative release and path tests |
| PR-09 | backend/cmd/api, internal/app, internal/config, domain workers/decorator | Route/middleware parity, startup cleanup and awaited shutdown; unchanged migrations/SQL |
| PR-10a | Flutter services/api_client.dart → core/http,session,platform and feature API facades | One transport/cookie policy; URL/session/Keychain/401 tests |
| PR-10b | Flutter app_state.dart → feature state owners | Session-generation barriers; logout/join/upload/history/reconnect/PTT race regressions |
| PR-11 | compose.yaml, deploy/compose*.yaml, docker config → deploy | Normalized service/project/volume/network/operator parity; install smoke on staging |
| PR-12 | docs navigation, backlog index views, tools/verify/dependencies,links | Canonical paths, import/link checks, old runtime wrappers removed after rewiring |

## Execution rules

For each implementation packet, read the exact imports and nearest tests;
write its focused failing cases, apply the minimum behavior-preserving change,
run those tests and the native build, and commit only inspected explicit paths.
Keep fixtures and changes for independent triggers in separate leaves.
Do not mix business changes into composition extraction or code changes into
the mechanical client relocation. Preserve applied migration names/content.

Common commands will expose doctor, check:contracts, test:backend, test:web,
test:flutter, build:server, build:android, build:windows, release:verify and
release:install. Entry commands call small tools, not duplicate implementations.

Each release receipt binds full source SHA, artifact checksums and OCI digests
to actual checks. Never replace an unknown test outcome with PASS. Hardware
media tests, client frame/rebuild timing and platform signing acceptance must
remain visibly open until measured on the relevant device/platform.

The existing backlog/tasks.yaml remains the task source; this document is the
execution sequence, not a second mutable acceptance registry. Record results
as dated evidence. Preserve older evidence as historical observations.

## Delivery result — 2026-10-02

Implementation merged in [PR #11](https://github.com/BOOHTACORD/BOOHTACORD/pull/11).
The [final staging record](../../../evidence/reorganization/2026-10-02-final-staging.json)
and [production receipt](../../../evidence/reorganization/2026-10-02-production-delivery.json)
bind native checks, measurements and signed delivery to their exact revisions.
Physical media/device and macOS/iOS acceptance remain explicitly NOT_RUN.
