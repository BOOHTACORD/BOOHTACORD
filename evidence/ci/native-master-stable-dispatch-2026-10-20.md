# Existing protected master dispatch — #396 / #386

Implementation base: `0c8278a3363cb98fd6933388e75809a7ad5aa75d`.

The owner chose to leave repository/environment/tag settings unchanged. The
separate native-release environment proposal in PR #487 remains unmerged.
The existing native workflows already offer a protected master dispatch with
`dry_run=false`, but preflight and the publisher rejected every such stable run.

The fix accepts that existing route only with an already-existing canonical
platform/version tag resolving to the exact reviewed master checkout/trigger.
The source receipt records the actual ref, event and raw trigger SHA. Before any
API write the publisher binds them to its actual execution, then retains the
existing remote tag checks, immutable assets and bounded retry behavior.
Candidate mode never gains publishing authority. Annotated tag triggers keep
their raw object SHA separately from the peeled source commit.

Tests were added first: the real-Git manual cases failed for all three platforms
and the shared publisher rejected the valid master case. Focused checks after
implementation: 22 Python source/assets/workflow/trust tests and 15 Node
publication/transport tests PASS, including missing/wrong tags, foreign refs,
non-dispatch events, mismatched or forged trigger context, candidate contracts,
annotated tags, foreign remote assets and changed remote tags.

No workflow job, environment, reviewer, permission, secret, signing model,
public asset filename or updater promotion is changed. Direct tag jobs remain
subject to the existing environment rules; master-only production settings use
the existing manual master route. No tag is created or retargeted by this fix.

Actual platform signing/publication: **NOT_RUN**. Independent production review,
native candidate acceptance and the other epic gates remain required. Synthetic
release bytes were never executed. This focused evidence does not close #396,
#386, #401 or epic #382.
