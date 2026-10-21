# Actions trust boundaries (CICD-12, #386)

All executable repository workflow jobs use approved GitHub-hosted images:
`ubuntu-24.04`, `windows-2022`, `macos-26` or the explicit `macos-26-intel`
matrix. The former Hetzner runner pool is retained as a historical operations
runbook; no workflow job targets its labels. Per-job hosted isolation does not
replace source guards, protected environments or narrow token scopes.

All active workflows, local composite actions and the inactive scheduler fixture reference external
Actions by reviewed full commit. `tools/verify/action_pins/pins.json` records the
original ref, resolved commit, upstream source URL and resolution date. The refs
were resolved read-only from the action owners' Git repositories, including peeled
tags. This pins the implementation already selected by those refs; it is not a
claim that all transitive action dependencies have been independently audited.
The Flutter setup uses a repository-owned composite and executes only the reviewed
installer Git blob; its SDK-only cache restore/save actions are independently pinned.
See [SDK cache boundaries](sdk-caches.md). Local action references must resolve to
reviewed, non-symlinked source and are included in pin/credential checks.
Dependabot proposes grouped Actions updates; a reviewer must update the registry
and review/test the matching commit in the same PR. Unregistered/mutable refs fail.

The pin verifier also checks declared source/permission/credential boundaries.
Legacy semantic validators receive an **inert normalized policy view only after
strict pin validation**. That view is generated under `.out`, never executed or
written into runnable workflows. Full SHA enforcement is not weakened to a tag check.
Actionlint 1.7.11 runs from source commit
`393031adb9afb225ee52ae2ccd7a5af5525e03e8`, using the approved Go toolchain.
Its entrypoint checks the actual Go version against `tools/toolchains.json` before
compilation; the contracts workflow selects that exact version explicitly.
It checks workflow structure/expressions/edges; separate ShellCheck/pyflakes analysis
is outside this invocation. The existing workflow/negative policy tests still run.

## Declared matrix

All workflow-root tokens are read-only. Write scopes exist only on the publishing/
promotion jobs below. These jobs may also build/package, but quality-only reusable
jobs remain read-only. A static comparison with #411 confirms that all seven publisher jobs retain their
existing effective write scopes and workflow queues; quality jobs lose inherited
write access. New ref/environment restrictions still require actual release QA; successful PR compilation does not prove release publishing.

| Workflow(s) | Source / runner / token | Credential or effect boundary |
| --- | --- | --- |
| `ci`, `ci-backend`, `ci-contracts`, `ci-flutter`, `ci-frontend`, `flutter-windows` | PR/merge-group/master/manual or reusable; GitHub-hosted Linux / Windows; read | No deployment/signing secrets, no inherited secrets; all applicable gates remain mandatory |
| `client-lifecycle-acceptance`, `next-client-acceptance`, `sfu-snapshot-measure` | PR/manual as declared; hosted; read | Owned isolated test fixtures, no production credentials |
| `qa-compatible-rollback` | PR/manual; hosted; contents/actions read | Owned isolated signing anchor, immutable retained sources, actual source-bound CI proofs; no production key |
| `build-server` | master; GitHub-hosted Linux gates and bundle job; read | Exact upstream/master/source-impact guard, production environment, all three receipts before bundle |
| `deploy-production` | trusted completed master producer; hosted; contents/actions read | Read-only route before environment; protected installer repeats provenance; serialized production writer |
| `install-retained-release`, `rehearse-compatible-rollback` | upstream master only; hosted; read | Production environment, existing pinned SSH/provenance/compatible rollback and non-cancellable writer lock |
| `audit-attachment-volume`, `qa08-active-upload`, `qa11-preflight` | upstream master only; hosted; read | Production environment now required before the existing SSH credential is exposed; dedicated read-only operator separation remains #399 |
| `flutter-macos` | fast fixtures plus explicit upstream-master full build; GitHub-hosted macOS; read | No persistent Mac or signing secret; exact Apple toolchain, source-bound artifacts; actual hosted acceptance remains separate (#400) |
| `android-release` | upstream master/manual or matching tag class; hosted; quality read, publisher contents write | Production environment, native quality dependency, signing queue, existing keystore/publisher verification |
| `windows-release` | upstream master/manual or matching tag class; hosted; publisher contents write | Production environment, existing package/version/identity/publish guards, native signing queue |
| `macos-release` | upstream matching macOS tag/manual; hosted; publisher contents write | Production environment, existing exact tag/version, ad-hoc signature/checksums; no notarization claim |
| `webrtc-macos-sdk` | hosted arm64/x64 build read; upstream master publish contents write | Production-protected publish only; immutable SDK recipe/assets; no SDK rebuild added to PR |
| `native-candidate-builds` | hosted recovery fixture read; Android signing upstream master only | Signing job enters production; legacy feature-branch push cannot access the keystore |
| `desktop-updater-acceptance`, `windows-updater-acceptance` | hosted fixture jobs read; publishers upstream master only | Production-protected fixture publishing; legacy feature-branch publish triggers intentionally receive no write-capable job |
| `promote-windows-client-update` | upstream master only; hosted | Production-protected catalog PR job needs contents/actions/PR write for branch push, candidate dispatch and PR creation; no direct master mutation |

Checkout credentials are not persisted, except the explicit trusted catalog PR job
that needs authenticated `git push`. Persistent runners, repository writes and
signing/SSH credentials are forbidden in PR/merge-group workflows. Secret inheritance
and `pull_request_target` are rejected. Job/step `continue-on-error` is forbidden
(the current workflows use none), including inside reusable child gates, so an
ignored child failure cannot masquerade as a successful aggregate dependency. Trusted guards are compared as complete
expressions; adding `|| true` does not satisfy the policy.

The linter's supported-runner catalog predates `macos-26-intel`. Its configured label
exception is backed by the official [hosted runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners);
it does not prove account availability, installed Xcode or SDK compatibility.

## Local checks

```sh
python3 -m unittest tools.verify.action_pins.test_policy tools.verify.action_pins.test_local tools.verify.action_pins.test_trust tools.verify.action_pins.test_lint
python3 -m tools.verify.action_pins.run
python3 -m tools.verify.action_pins.lint
```

## External acceptance still required

The declarations above fail closed but cannot configure or attest GitHub settings.
Do not close #386 or parent #382 solely because these policy tests/PR checks pass.
The settings page was unavailable in the in-app browser (signed out, 404); no login,
security setting, credential or environment rule was changed through the UI.
Read-only API follow-up returned HTTP 403 (`Resource not accessible by integration`)
for classic master branch protection, and an empty repository ruleset collection.
The empty collection does not attest classic protection or environment/runner settings.

- Read back production environment reviewers, allowed master/native-tag refs and
  bypass policy. New native/diagnostic environment gates can block until approved;
  they must not be removed or treated as PASS to make publishing work.
- Read back production environment reviewers, allowed refs and bypass policy.
  Hosted runner selection is enforced in source policy; a job `if` alone is not
  protection against a modified untrusted workflow.
- Run approved native publishing QA/dry-runs with the narrowed scopes; keep missing
  credentials/approval/device/runner evidence BLOCKED. Do not fabricate a release.
- Retain actual exact-source signing/bundle/compatible rollback regression evidence.
  Old receipts/PR test success cannot attest a different merge SHA.

The owner chose to configure the separate `ci-required` status personally (#385).
This implementation does not change repository rules, tag rules, runner groups or
production environment settings, and does not request Keychain access.
