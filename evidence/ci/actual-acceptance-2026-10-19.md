# #398 — risk-based actual acceptance implementation

Date: 2026-10-19. Parent: #382. Baseline: 911d7c7989c6043a093bca1f88d8229ce3beab42.

Implementation: versioned conservative risk map and common selector outputs;
mandatory `actual` dependency of `ci-required`; reusable real lifecycle/next/SFU
controllers in separate disposable hosted VMs; exact owner labels, process-group
termination, resource cleanup and finite sanitized evidence fan-in; original
reports/captures retained with exact source/run/attempt and integrity validation.
Manual wrappers avoid duplicate automatic PR stacks. Native QA publication now
requires explicit protected upstream-master dispatch. Compatible rollback takes
verified source/run inputs; canonical three-field builder receipts and observed
CI provenance are separated. Physical and full installed-update acceptance remain
separate from automatic browser/SFU proof.

## Focused validation — PASS

The focused set covers 61 cases across actual risk routing, namespace/cleanup,
source/run-bound evidence, artifact tamper/missing selection, mandatory aggregate,
workflow/trust boundaries, original resource guards, CI proof and native fixture
ownership. In the final set, 60 passed and one temporary-directory fixture hit
macOS's `/var` symlink guard; that fixture now resolves its canonical path and
both affected fan-in tests passed on rerun. No production guard was relaxed.

- `python -m unittest tools.ci.actual_acceptance.test_plan ...test_session ...test_validation ...test_fan_in ...test_manual_inputs ...test_workflow ...test_run tools.ci.required_gate.test_validation ...test_run tools.verify.workflows.test_selection tools.verify.action_pins.test_trust tools.qa.client_lifecycle.test_services tools.qa.critical_client_acceptance.test_stack tools.qa.compatible_rollback.test_receipt_projection ...test_ci_proof tools.qa.desktop_updates.test_windows_journey tools.ci.toolchains.test_workflows`.
- `actionlint 1.7.11 -shellcheck= -pyflakes=`: PASS.
- `python -m tools.verify.workflows.selection`: PASS.
- `python -m tools.verify.action_pins.run`: PASS (32 workflows / 2 local actions).
- `python -m tools.ci.toolchains.workflows` and `...auxiliary`: PASS.
- `tools/verify/spec_traceability/verify-spec-traceability.ps1`: PASS_INDEX_ONLY,
  39 requirements. The approved Windows brief is unavailable on this host.

## Actual acceptance — NOT_RUN

New hosted runtime profiles, simultaneous-PR exercise, cancellation/cleanup drill,
critical-path before/after, repeated flake measurement, full compatible rollback,
owner-signed native installed N→N+1 and physical devices were not run in this
implementation change. The owner requested implementation first with focused
checks and deferred expensive runs. Neither local VM was started. A green local
unit result does not establish a hosted, release or physical PASS. #398 remains
open until the separate acceptance is recorded. Repository protection settings
were not changed (#385 belongs to the owner).
# Follow-up actual acceptance, 20 October

The original implementation-only NOT_RUN boundary below is historical. Retained
parallel PR lifecycle runs now passed independent full artifact/fan-in replay,
206 seconds of actual controller overlap, separate owner/port/account-stack
namespaces and cleanup. All three current profiles passed in PR457. The 78-run
observation window retains failures/cancellations and unknown flake causes.
See `combined-acceptance-2026-10-20.md`, `parallel-actual-final-2026-10-20.json`
and `after-observation-2026-10-20.json`. Physical/device and protected native
release checks remain separate and are not certified by this acceptance.
