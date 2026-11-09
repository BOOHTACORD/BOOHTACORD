# PR 695: diagnostic markers and successful CI repeat

2026-11-09. PR head `c96af5782b34d968fbc43de831cf816840316de5`, GitHub
Actions run `42560868692`, attempt 1: completed SUCCESS, 27/27 jobs including
`actual / runtime (lifecycle)`, Windows GUI/SFU and `ci-required`.

The previous head `ae52bdd4d2717e7f324e301430e095bc016ae4d1` failed lifecycle
in run `42559087035`; its exact failing assertion is unknown, as documented in
`issue-648-pr695-ci-2026-11-09.md`. The new head extracts the existing preview
checks into a responsibility-focused helper and adds five fixed allowlisted
milestones after checks complete. Assertions, timeouts and prior screenshot
operations remain unchanged. A textual comparison of the extracted block to
the prior head matched after excluding only the new markers. The CI report
retains short-stage geometry for the related markers. A pre-change focused
allowlist test failed and then passed; 27 actual-acceptance controller tests,
12 neighboring Node tests and JavaScript syntax checks passed locally.
The first attempted Windows Python run of Linux-only controller tests failed
because `fcntl` is unavailable; the reported successful suite ran under WSL.

One passing retry does not determine the earlier failure's cause or prove
its recurrence impossible. CI does not replace the canonical local feature
gate, physical devices or production acceptance. No merge or deployment was
performed.
