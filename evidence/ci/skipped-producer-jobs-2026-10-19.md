# #384 follow-up: actual skipped reusable-job identities

The ordinary documentation-only proof (PR #413, run 39163108152) exposed a wrong
unit model: GitHub reports a skipped reusable call with its caller name (`backend`,
`frontend`, etc.), while a running child uses `caller / child`. Build server's
callers are `backend`, `web` and `contracts`. The initial route model incorrectly
kept qualified names for skipped wrappers. #384 was reopened after the initial
merge; it must remain open until an actual master no-release route is observed.

The corrected decoder requires exactly one identity per gate across both forms.
Release-bearing producers still require qualified successful children. Non-release
producers require bare skipped wrappers, skipped bundle and successful selector.
Qualified internal skips, bare successful wrappers, mixed/duplicate aliases,
failed/cancelled/incomplete/foreign producer evidence remain invalid. The existing
producer/source/workflow/provenance and protected install checks are unchanged.

Tests were changed first: the real wrapper-name shape failed, while the old model
incorrectly accepted internal skips and ambiguous aliases. Seven focused decoder
tests now pass, alongside existing producer/workflow/routing regression tests.
Actual GitHub full applicable CI and a master docs-only Build server -> Deploy
no-install observation are pending. This local test record cannot close #384.
