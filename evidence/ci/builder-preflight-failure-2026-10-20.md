# Builder preflight failure diagnostics — #394 / CICD-10

## Original observation (not a successful release)

Protected master producer [39374816147](https://github.com/Egkurilov/BOOHTACORD/actions/runs/39374816147)
at `88f42cfae324826f73e7b55810ee10f510b7f4f7`, attempt1, passed all13 quality
jobs, then ran bundle job118476420742 from09:38:49 to09:40:25UTC after review.
The bundle step failed. Verified-release upload was skipped; no installation
started and no signed bundle from this attempt was uploaded.

The original timing ZIP, artifact12255350899,655bytes, SHA-256
`dbca6ee7fc9379ae56cce2c2c38e299116d51eb31d89c04a5a6741a03b2d2037`,
was independently downloaded and digest checked. Its report is FAIL:

| Stage | Seconds | Outcome |
| --- | ---: | --- |
| source_archive | 2.246454 | PASS |
| source_extract | 1.851998 | PASS |
| assets | 8.381999 | PASS |
| buildx_setup | 0.932241 | PASS |
| owned_builder | 60.719711 | FAIL |
| nested cleanup | 30.280597 | FAIL |

There is no `filesystem_before` or image/smoke/signature stage. The sanitized
terminal exception was `Owned builder cleanup is incomplete; journal retained`.
Code inspection shows the first metadata probe failed before assigning resource
state; the unconditional finalizer probes Docker again and masks the initial
exception. The roughly30-second intervals suggest a Docker command timeout,
but the original log does **not** prove whether daemon info or image inventory
timed out. The Ubuntu exception-reporting hook also failed afterward; this is a
secondary reporting error, not proof of the original Docker cause. Raw private
logs and command output are not published in this record.

## Focused correction

The resource controller now avoids a duplicate Docker probe only if no resources
were acquired and the exclusive lease has no journal. It retains FAIL, releases
the lease/signal handler and does not fabricate a filesystem measurement. A
previous orphan still blocks cleanup success and remains intact. Normal owned
cleanup, daemon/label/reference/user/mount verification and recovery are retained.
No global prune, permission change, production mutation or automatic retry was
added.

Docker command failures now carry finite operation/reason categories without
argv, paths, output or raw exception messages. Setup and cleanup diagnostics are
kept separately in sanitized metrics, including when cleanup also fails.

Tests were added first: the absent exception type initially failed imports;
after adding only that type, all affected behavior regressions still failed
(8 errors across21 tests), confirming masking, missing metadata and unsafe
generic classification. The implemented behavior passes the focused native
Python tests, including no-probe/no-mutation initial failure, untouched orphan
journal, refused cleanup with retained journal, bounded output, encoding,
nonzero exit, timeout, OS failure and unknown-operation redaction.

Final native check: all69 tests in the14 `tools/build/server/test_*.py` modules
PASS (0.142s). An initial `unittest discover -s tools/build/server -t .`
invocation stopped before running tests because this is a namespace directory;
the corrected explicit module loader passed without changing test assertions.
Ordinary contracts CI discovers the new module through
`tools.verify.python_tests.run`; no workflow or settings change is needed.

This fixes failure reporting and redundant preflight work, **not** the as-yet
unverified Docker host cause. Actual current-source signed bundle, smoke and
self-hosted cold/warm/disk acceptance remain NOT_RUN. #394 and the parent gate
stay open. Existing environment/ruleset/tag settings remain unchanged.
