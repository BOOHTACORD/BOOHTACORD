# Risk-based actual acceptance (#398)

The versioned authority is `tools/ci/actual_acceptance/plan-v1.json`.
The common PR/merge-queue selector emits its digest, ordered profiles and separate
release/physical requirements. Unknown or unreadable diffs select every profile
and every release/physical requirement. Documentation-only changes select none.
`ci-required` waits for the reusable actual workflow and rejects failure,
cancellation, missing evidence and unexpected skips. Repository protection remains
an owner-controlled setting (#385).

## Scenario inventory and mandatory routing

| Area / trigger | Actual profile and original controller | Assertions / evidence | Owner / budget |
| --- | --- | --- | --- |
| Auth, secure cookies, ACL, channels, guild, lifecycle, attachments | `lifecycle`: refresh baseline, critical client journeys at 1440/1024, upload reservations | Real TLS API/PostgreSQL/SFU, persisted state after restart, authorization/observer diagnostics, original source-bound reports and synthetic captures | CI/QA; 1500s controller deadline |
| DM, composer, upload queue, unread/search context | `next` plus `lifecycle`: next-client limited/unlimited cases | Real API/PostgreSQL/SFU and production Web client; managed upload and protected history navigation; actual window visibility with Xvfb/Openbox | Web/QA; 1200s controller deadline |
| Voice, screen sharing, SFU transport/control | `sfu` plus lifecycle/next for general runtime changes | Real SFU/API/PostgreSQL and source-bound control/snapshot measurements | Media/QA; 900s controller deadline |
| Backend, Web, contracts, CI/QA/build/toolchain changes | All three automatic profiles | Conservative coverage; component unit/browser/native gates remain independently mandatory | CI/QA; independent fresh VMs |
| Deployment/server delivery | All automatic profiles + `compatible-rollback` release requirement | Signed compatible pair, real retained master CI receipts, two browser observers, scoped nested Docker daemon | Release/QA; manual `qa-compatible-rollback.yaml`, 60min |
| Flutter/native/updater | All automatic profiles + Windows/macOS installed-update release requirements + physical requirements | Mandatory Windows CI recovery/GUI remains in `flutter-windows.yaml`; full installed N→N+1 and macOS signing/Keychain are separate acceptance | Native/QA; explicit trusted QA dispatch only |
| Unknown path | Every automatic, release and physical requirement | Conservative fallback, never inferred PASS | CI/QA |

Automatic browser/SFU acceptance does **not** prove physical microphone/output,
OS screen capture, actual desktop installed-update/signing, iOS/Android hardware,
or capacity. #60, #62, #335 and #337 retain their separate evidence. The selector's
`actual_release_required` / `actual_physical_required` outputs are requirements,
not PASS receipts. Release readiness (#402) must consume source-bound acceptance
or remain BLOCKED. A green PR gate alone does not authorize release.

## Reusable isolated execution

`ci-actual-acceptance.yaml` runs each selected profile in its own **fresh
GitHub-hosted Ubuntu VM**, with its own localhost port namespace, filesystem,
synthetic accounts and service credentials. Two concurrent PRs therefore never
share numeric localhost ports or accounts. Running two cases on one personal or
self-hosted VM is explicitly refused; an exclusive VM lease also prevents local
controller overlap. Each run/attempt/job/profile has a random exact Docker-owner
label and an artifact name containing source/run/attempt/profile. Controllers
retain their existing resource guards. The finalizer only deletes Docker objects
whose exact label is rechecked before removal. No global prune or production
endpoint, data, credential, host socket, SSH, publisher key or API token is used
by product processes. Nested rollback Docker remains a separate disposable job.

Each operation belongs to the fixed controller catalog: dispatch cannot inject a
command. Subprocesses have process-group cancellation, total time/log bounds and
private logs. Always-run artifact upload retains only finite, sanitized original
JSON results and deduplicated synthetic PNGs. Fan-in validates every selected
profile, source, run, attempt, risk-map digest, complete report list, hashes,
cleanup and exact public file inventory. Missing evidence/cleanup is red, not an
allowed skip. VM disposal is the last boundary on forcible host termination;
a cancelled run cannot pass.

The former three PR workflows now are manual wrappers around this same harness;
only CI owns automatic risk routing, avoiding duplicate runtime stacks. No writes
or signing permissions are available to PR code, including forks.

## Parameterized trusted QA

Rollback takes exact current/previous 40-character source commits and their
successful master producer run IDs, validates the inputs, fetches only those
objects and authenticates the original three gate jobs through the GitHub API.
Existing source/tree/runtime and compatible-rollback checks are unchanged.
Historical `ci-inputs.json` is an example record, no longer a runnable workflow
input. Canonical builder receipts contain exactly source/gate/status; authenticated
job/run provenance is stored separately rather than breaking that contract.

Native QA workflows accept only explicit manual `master` dispatch in the upstream
repository, use the protected environment and require `publish_qa=true` (default
false) before any QA release creation. Fixed 78/79 identities are deliberately
versioned **test fixtures**, never stable releases. Their source is the actual
checkout. Windows additionally requires an immutable commit containing its
owner-signed, exact-source envelope; a mutable feature branch is never consulted.
The shipping client still verifies the publisher signature and package digest.
Missing fixture/signing/native runtime is a failed/blocked acceptance. Packaging
macOS alone does not claim that an installed update passed.

## Measurement and pending actual evidence

Every automatic receipt records total elapsed seconds and original scenario
measurements. Budgets above are bounds, **not measured performance results**.
Focused local validation is in `evidence/ci/actual-acceptance-2026-10-19.md`.
New hosted profiles, simultaneous-PR exercise, cancellation drill, PR critical
path before/after, repeated flake sample and physical/release acceptance are
**NOT_RUN** in this implementation change, per the owner's implementation-first
instruction. #398 stays open until that acceptance is recorded.
