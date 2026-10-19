# CICD-18 / #387 preparation

Status: **NOT_RUN** for implementation/workflow, retention and runtime acceptance.
Local branch `codex/issue387-artifact-policy` starts from #393 candidatef98d6f56
while that PR's real Android/Windows jobs execute. Publication/merge must wait for
#393 master acceptance. Primary dirty user files remain untouched.

Read issue #387, its dependencies #383/#393, existing uploads/retention rules,
native publication consumers and retained fixture references. Selected leaf
CICD-18. Focused retention/naming tests are written before the implementation.
The short lifetime is limited to successful transient synthetic PR captures;
release and acceptance classes, failures and unknown contexts retain 30 days.

Read-only pre-#393 metadata inventory: original PR has20 artifacts/253.06MiB;
same-master CI+Build server has35 archives/382685999bytes. These are prerequisite
observations only. The accepted after-#393 producer graph must provide the real
baseline before measuring #387; no reduction or privacy PASS is claimed here.
Actual contents, manifests/checksums/source identity, matched PR/master/tag/QA
scenarios and install/rollback paths remain to be checked before closure.

Eight focused tests first failed on missing modules, then passed after adding
the pure retention and immutable naming functions. They preserve all five
release/package/acceptance/failure classes at30days, shorten only successful
transient PR captures, retain master/tag/merge-queue/manual/unknown contexts,
reject unknown roles and prevent retry/source/run name collisions or private
input echo. Indexed traceability passes for39 requirements (PASS_INDEX_ONLY).
No upload, publisher, workflow or live retention changes have been made.

The complete local Python suite passes **779 tests in 44.503 seconds** on this
foundation. This does not turn the pending artifact-policy acceptance into PASS.
