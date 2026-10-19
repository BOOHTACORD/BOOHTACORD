# #396 — shared native release contracts

Implementation: exact version/tag/master-reachable source authority; annotated
and lightweight tag peeling; complete platform asset/signature/hash contracts;
shared draft-first publisher with immutable published assets, exact source/notes,
bounded lost-response recovery and remote digest readback; protected per-platform
signing/build jobs; master/matching-tag dry-run candidates which cannot publish.
The obsolete fixed feature-branch/run-ID candidate workflow is removed; its
standalone Unicode/path C++ and portable recovery preflight checks move to the
mandatory Windows native-unit job. iOS is
explicitly outside this three-platform automation and remains NOT_RUN.

Focused TDD initially failed on missing source/workflow/publisher modules. Local
Git tests exercise real annotated tags and reject unrelated master history.
Asset fixtures use the existing real metadata/component writer, hashes and ZIP
inspection with synthetic executable/APK/archive contents; no such bytes are
executed. Negative cases cover mismatched source/version/signature, missing or
extra files, bad checksums, dirty source, QA Windows packages and traversal.
Synthetic HTTP tests cover draft-first publication, identical read-only retry,
lost create/upload/PATCH responses, foreign assets, moving/annotated tag refs,
candidate/retry/local-byte rejection and all three platform metadata paths.

Existing Android/Windows publisher regressions, native metadata/component
publication, source trust and workflow guards are included. The macOS packaging
shell fixture is a basic packaging test, not a real new app build.

Actual Android/Windows/macOS dry-run builds on their platform runners, actual
new release publication, updater/physical acceptance and iOS/TestFlight:
**NOT_RUN** for this implementation. Per owner, long repeated native runs are
deferred until implementation is complete. #396 remains open for that combined
acceptance. No signing keys or repository protection settings changed.

Final targeted results: **37 Python tests PASS in 2.835 s**; **15 Node tests
PASS** across shared and existing publishers (the final affected shared suite:
6 PASS in 65 ms). macOS packaging shell fixture: **PASS**, including expected
signature/version rejection cases. Workflow policy: **PASS** (30 workflows,
2 local actions); actionlint 1.7.11 and diff check: **PASS**. Required spec
traceability: **PASS_INDEX_ONLY**, 39 requirements; approved external brief
unavailable on this host. Full native platform builds were not repeated locally.
