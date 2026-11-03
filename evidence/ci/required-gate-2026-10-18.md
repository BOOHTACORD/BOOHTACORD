# CICD-03 / #385: stable required aggregate

Code and scheduler validation: PASS. Repository required-status setting: BLOCKED
The owner chose to configure the required status personally; actual settings
readback is still pending as explicitly required by #385.
The issue and parent #382 must remain open until their outstanding criteria pass.

Thirteen focused validator/command/workflow-policy tests passed, including complete
role matrices, selected failure/cancel/skip/missing, invalid/partial/stale selector
outputs, expected irrelevant skips, current dependency-map digest, malformed JSON,
role renaming and workflow/continue-on-error/shell interpolation guard failures.
The tests initially failed before implementation. Traceability: 39 indexed
requirements PASS_INDEX_ONLY (approved Windows brief unavailable on this Mac).

A real isolated GitHub Actions scheduler fixture was tested in disposable PR
[#410](https://github.com/BOOHTACORD/BOOHTACORD/pull/410), closed **without merge**:

- [Negative run 39159662907](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/39159662907):
  selector/contracts succeeded, selected backend fixture failed, three irrelevant
  jobs skipped, and actual `ci-required` failed. Its log contained the production
  validator's failure message.
- [Positive run 39159738354](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/39159738354):
  the same selected fixture succeeded, irrelevant jobs stayed skipped, and actual
  `ci-required` succeeded with the production validator's success message.

The two proof heads use byte-identical production validator/map source, verified
with Git objects. This proves Actions dependency/skip/result semantics, not backend,
Windows, Android, iOS, media or UI product acceptance. The ordinary CI PR trigger
was suppressed only in that throwaway branch to avoid running unrelated native
builds. That suppression and active proof workflow are **not** in the implementation.
No required fixture/aggregate used `continue-on-error` or production credentials.

Exact heads/check IDs/status URLs are in
[the machine receipt](required-gate-scheduler-2026-10-18.json). The inactive fixture,
local tests, status semantics, merge-queue fallback and separately approved owner
settings procedure are documented in [required-gate.md](../../docs/ci/required-gate.md).
The actual implementation retains every selected existing product gate.
