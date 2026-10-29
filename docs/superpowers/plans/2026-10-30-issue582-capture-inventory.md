# Issue 582 synthetic capture inventory implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Execution here is inline under the existing CI integration delegation; no additional agent is dispatched.

**Goal:** Retain the two reviewed synthetic landscape captures without accepting arbitrary images.
**Architecture:** Add their exact producer filenames to the existing finite recent-bug inventory. Keep the publisher's exact-set, freshness, context, privacy and integrity checks unchanged.
**Tech Stack:** Python unittest, existing Flutter screenshot producer and GitHub Actions.

Operating brief: small_direct; route tools/ci/flutter_gates/recent_bug_visuals; base f289e05f; one inventory file and two focused test files; target100/hard120 lines; no Dart, contracts, pins, workflow conditions or media changes.
Native edge: CI Flutter dart -> artifact_policy.run finish -> inventory.complete -> artifacts.VISUALS -> recent_bug_visuals.VISUALS.
Stop when RED/GREEN is retained, nearest publication tests pass and the CI-only commit is published to PR606. Physical APK acceptance remains separate.

### Task 1: Require the approved scenarios

Files: add `tools/ci/flutter_gates/test_issue582_capture_inventory.py`; update `tools/ci/flutter_gates/test_artifacts.py`.
- [x] Add a test requiring both exact producer names and rejecting either missing capture.
- [x] Add a test rejecting lowercase-iOS aliases, unreviewed platforms and private-looking extras.
- [x] Change the existing mandatory count assertion from165 to167.
- [x] Run `python -m unittest tools.ci.flutter_gates.test_issue582_capture_inventory tools.ci.flutter_gates.test_artifacts`; expect missing-name/count failures before implementation.

Core assertions:
```python
expected = {'issue582-android-landscape-ime.png', 'issue582-iOS-landscape-ime.png'}
assert expected <= set(artifacts.VISUALS)
capture_inventory.complete('flutter', dict.fromkeys(artifacts.VISUALS))
for name in expected:
    with self.assertRaises(ValueError):
        capture_inventory.complete('flutter', dict.fromkeys(
            item for item in artifacts.VISUALS if item != name))
```

### Task 2: Register only the actual producer names

File: `tools/ci/flutter_gates/recent_bug_visuals.py`.
- [x] Extend its existing tuple exactly:
```python
'issue582-android-landscape-ime.png',
'issue582-iOS-landscape-ime.png',
```
- [x] Mention582 in its module description; retain all prior scenarios.
- [x] Run the two typed test modules plus artifact_policy capture inventory/publication/run/context tests. Expect no failures or skips.
- [x] Record command, RED/GREEN log hashes and bounded publication scope in `evidence/qa/issue582-capture-inventory-2026-10-30.json`.

### Task 3: Publish the bounded integration

- [ ] Inspect status, exact changed file sizes and diff; exclude generated media and registrants.
- [ ] Commit only the inventory, two typed tests, this plan and sanitized evidence.
- [ ] Verify PR606 remote head stillf289e05f, then fast-forward its branch to this descendant commit.
- [ ] Require a fresh full hosted run; keep582 open until root-owned physical positive Send and PC receipt.
