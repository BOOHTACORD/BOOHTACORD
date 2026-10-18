# #384 follow-up: actual skipped reusable-job identities

The ordinary documentation-only proof (PR #413, run 39163108152) exposed a wrong
unit model: GitHub reports a skipped reusable call with its caller name (`backend`,
`frontend`, etc.), while a running child uses `caller / child`. Build server's
callers are `backend`, `web` and `contracts`. The initial route model incorrectly
kept qualified names for skipped wrappers. #384 was reopened after the initial
merge; it was kept open pending an actual master no-release route.

The corrected decoder requires exactly one identity per gate across both forms.
Release-bearing producers still require qualified successful children. Non-release
producers require bare skipped wrappers, skipped bundle and successful selector.
Qualified internal skips, bare successful wrappers, mixed/duplicate aliases,
failed/cancelled/incomplete/foreign producer evidence remain invalid. The existing
producer/source/workflow/provenance and protected install checks are unchanged.

Tests were changed first: the real wrapper-name shape failed, while the old model
incorrectly accepted internal skips and ambiguous aliases. Seven focused decoder
tests now pass, alongside existing producer/workflow/routing regression tests.
At this local checkpoint, actual GitHub acceptance was still pending. Subsequent
full applicable CI passed for #416 and the fix was merged. The actual master
docs-only producer/consumer acceptance now passes with an explicit triggering
producer ID; see [the dated observation](master-nonrelease-route-2026-10-19.md)
and its machine-readable source/run/job/log bindings. Local tests alone did not
close the gate.
