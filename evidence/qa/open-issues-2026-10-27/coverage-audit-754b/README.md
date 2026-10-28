# Read-only QA intake and coverage audit

The 37 original QA gates remain open and the goal remains IN_PROGRESS.
All 480 criterion texts are unchanged and occur literally in the original issue
bodies. All 13 original prose/table qualifiers remain bound to their whole gates.
The fresh 37-source snapshot is from 2026-10-28T23:01:44Z. All original bodies are
exact prefixes; 10 subsequent suffixes contain evidence/qualifier updates, with
no title/core edits or new acceptance requirements found.

This review freezes the 95-set matrix at evidence commit e06c9019. Later parent
updates to 62/595 and new phone work are outside that snapshot. Matrix changes
since the initial 2802362 data commit add only QA62 evidence links; criterion
texts/statuses, cases and qualifiers are unchanged across that interval.

- 37 issue states: 12 BLOCKED, 13 PARTIAL, 5 PENDING, 7 FAIL; zero gate PASS.
- 480 rows: 160 BLOCKED, 54 PARTIAL, 239 NOT_RUN, 19 FAIL, 8 PASS.
- 391 acceptance rows include 7 PASS; the eighth PASS row is an evidence requirement.
- 95 catalogued sets: 26 PASS, 42 PASS_SCOPED, 19 FAIL, 2 PARTIAL, 2 NOT_RUN, 4 BLOCKED.
  The catalogue size is not an executed-test count or whole-gate acceptance rate.
- 359 evidence/result references and JSON pointers resolve; case IDs are valid.
- 306 acceptance rows have no direct scoped-case link. This is a routing/execution
  gap; missing links alone do not prove an external blocker or product failure.

Review.json provides exact metadata corrections without editing the matrix:

- Windows blocker pointers /issues/25/blockers/0, /issues/27/blockers/0 and
  /issues/29/blockers/0 still say traversal NOT_RUN. Later seven-section read-only
  evidence exists. The 120s human input lease has expired; complete keyboard,
  focus, IME, resize/large-text and accessibility acceptance is still unproven.
- PUBLIC-update-catalog is a dated 503/no-store failure relevant to I249.C4 with
  no row/case link. QA249 remains FAIL; a fresh endpoint result is not inferred.
- DB592 already exists; the case's old 'Bug creation pending' fragment is stale.
- Closed implementation bugs 584/585/586/587/589 do not close physical or
  current-deployment acceptance. Preserve historical receipts and require the
  exact new-candidate result before any future status promotion.

Three independent local facets remain unrun: I287.C8 reaction concurrency/replay
and TEXT pins; I240.C17 media-report/lease correlation ownership; I287.C3 actual
PostgreSQL query-plan receipts. Existing DST/cursor/ACL tests should not be
repeated without cause. Each proposed packet needs fresh contract/ownership
preflight and exact own cleanup. Android TalkBack/system sharing and Windows
resize/full keyboard are conditional device packets, not missing-platform claims.

Physical Mac/iPhone/Pixel, human audibility/study evidence, approved notification
provider/cohort and browser URL-confidence policy have separate prerequisites.
PR596's retained current CI metadata proves 27/27 and the merged tested tree;
the separately running signing 40784080135 is not signing/install/physical PASS.

Both historical validator entrypoints were read, never executed. The canonical
B validator uses dynamic len(cases), hard 480 rows and writes data. The timeout
publication validator hardcodes 95/first93/base 623e and also writes data. A future
97-set publication needs a fresh e06c-bound preservation check.

Commands executed here: python -B -X utf8 .out/qa-intake-coverage-754b/audit.py
and review.py, followed by the metadata sealer. Only filesystem/data assertions
and read-only GitHub connector fetch/search were used. Runtime/API mutation,
browser/CUA/device action, native product-test rerun, source/B/Git/GitHub write: 0.
One exploratory labels=None projection TypeError is retained as a controller
diagnostic; its normalized metadata retry did not change product state.

Export only the closed allowlist in public-review.json. Raw issue bodies, actors,
private snapshots, detailed reference inventory and raw command logs are excluded.
This is a source/coverage audit, not runtime acceptance or goal completion.
