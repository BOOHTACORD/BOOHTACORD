# Issue 687: complete local Web gate on Windows

Status: FAIL. Do not use scoped audio successes as a passing full product gate.
Source ac2aa8133e23f702e83ff4be11da566f00409fcb, source stability PASS.
Report: local `.out/local-features/20261114-180026/index.html`.

Web unit/build/accessibility, authentication session retention, connection
status, conversation actions, mentions, message social, password visibility,
quick jump, search dates, settings and disconnect-notice stages passed.
Several visual/zoom stages failed; screen-profile remained BLOCKED.
At 200% native zoom, a 1440px outer window produced 709 CSS pixels instead of
the chat test's assumed 720. Its test and shared zoom helper are unchanged
against origin/master. Screenshot comparisons on this Windows host also failed;
no baseline was approved. This does not establish their complete cause.

Audio microcopy tests failed on an ambiguous `.audio-check-details summary`:
both device-check help and the Windows communications-volume help match.
This is a test-selection failure, not an observed Auto/media failure.
Both actual-stack widths failed before stack startup because Windows
CreateProcess cannot find the bare `npm` executable used by that runner.
The report JSON was emitted in host cp1251 and was decoded explicitly for
inspection. These harness and product gates remain unresolved.

The run produced 634 images; they have not all been reviewed. Scoped Windows
Flutter audio observations are in the cold-start evidence. No visual release
or full acceptance decision follows from these results.

CI on ac2aa8133 separately failed the Web dependency boundary: the newly moved
unit fixture was outside the image's copied src tree. It has now been returned
beside its typed tests (mapped as test support), preserving the Docker boundary.
The native dependency verifier passes for 1,329 files and all 126 scoped noise
tests pass after that repair. Research Web/fixtures/cache workflows on ac2aa8133
passed; the corrected head requires a new complete CI execution.
No release or server deployment.
