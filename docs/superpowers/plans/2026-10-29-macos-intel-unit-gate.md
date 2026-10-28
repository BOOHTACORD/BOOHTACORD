# Native macOS unit runner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
> Those optional subskills are not installed in this session. Use native collaboration with an implementation worker and independent specification/code review; do not pause for another execution-choice question. The user already requested parallel agents and completion of hosted CI.

**Goal:** Run the existing mandatory eight Apple-only unit tests on GitHub's supported macOS26 Intel pool after the ARM pool could not allocate a runner.

**Architecture:** Change only the pinned host of the `macos` profile and its exact runner policy. Keep the same Darwin test entrypoint, named outcomes, zero-skip enforcement, SDK/action pins, cache architecture isolation, four required profiles, current-source/run/attempt receipts, aggregate and signing dependency. Full SDK ARM/Intel builds and physical media acceptance remain separate.

**Tech Stack:** GitHub Actions, Python unittest/PyYAML, Flutter3.47.7/Dart3.13.5.

**Packet:** small_direct implementation; leaf tools/ci/flutter_gates; base b7f1c3ad438201c0461ed4858d97df6917815ceb. Q/local-qa-stack and B/android-qa remain untouched by this worker. Preserve source behavior; no43 consolidation decisions.

### Task 1: Qualify and pin the Intel unit host

**Files:**
- Modify: `.github/workflows/ci-flutter.yaml` (only macos.runs-on)
- Modify: `tools/ci/flutter_gates/workflow.py` (only exact macos runner constraint)
- Test: `tools/ci/flutter_gates/test_workflow.py`
- Document: `docs/ci/flutter-gates.md` (host and unchanged scope)

- [ ] Run the existing baseline before edits:

```text
python -m unittest tools.ci.flutter_gates.test_workflow
```

Use an existing project-compatible interpreter with PyYAML; a missing dependency is a bootstrap diagnostic, not the intended RED result.

- [ ] Add focused tests before implementation, using the existing WorkflowTests.document helper:

```python
def test_reviewed_intel_macos_profile_is_accepted(self):
    document = self.document()
    document['jobs']['macos']['runs-on'] = 'macos-26-intel'
    workflow.validate(document)

def test_macos_profile_rejects_unreviewed_or_non_apple_hosts(self):
    for host in ('macos-latest', 'macos-26', 'macos-15-intel',
                 'ubuntu-24.04', ['self-hosted', 'macos']):
        document = self.document()
        document['jobs']['macos']['runs-on'] = host
        with self.subTest(host=host), self.assertRaises(ValueError):
            workflow.validate(document)
```

- [ ] Run the focused suite. Require an actual policy rejection for the Intel positive control and acceptance of the formerly selected ARM host in the negative control as the RED evidence. Preserve exact outputs.
- [ ] Apply the two minimal implementation edits:

```yaml
  macos:
    runs-on: macos-26-intel
```

```python
require(job.get('runs-on') == ('macos-26-intel' if profile == 'macos' else GITHUB_LINUX)
        and job.get('timeout-minutes') == timeout
        and not any(job.get(k) for k in ('if', 'needs', 'continue-on-error', 'environment', 'secrets')))
```

Preserve the existing formatter/layout when replacing this condition. Do not touch any other job field or allow arbitrary runner expressions.

- [ ] State in flutter-gates.md that the unit host is native Intel/macOS26, the same eight Darwin cases reject skips, and ARM/Intel SDK builds/physical Mac acceptance remain distinct.
- [ ] Run focused and neighboring native policy tests:

```powershell
python -m unittest tools.ci.flutter_gates.test_workflow
$flutterGateTests = @(rg --files tools/ci/flutter_gates -g 'test_*.py' | Sort-Object) -replace '[\\/]', '.' -replace '\.py$', ''
python -m unittest @flutterGateTests
$macosUnitTests = @(rg --files tools/verify/macos_unit -g 'test_*.py' | Sort-Object) -replace '[\\/]', '.' -replace '\.py$', ''
python -m unittest @macosUnitTests
pwsh -NoProfile -File tools/verify/contracts/verify-contracts.ps1
```

On Python 3.12.10 these leaf directories are namespace packages; `unittest
discover -t .` fails before discovery (`Start directory is not importable`).
The bounded module lists execute every test file in each leaf without changing
package structure. Preserve the original discovery diagnostics separately.

Record actual discovery/skips. Do not run the real Darwin profile locally on Windows or claim physical acceptance. Follow exact SDK setup test edges if additional changed policy checks require them; do not broaden source search.

- [ ] Inspect git status and changed file sizes, review the full diff, stage only the named paths, and commit the bounded change. Preserve the approved source/SDK inputs. Root will open/review/merge the PR only after actual checks.

### Task 2: Hosted qualification and signed candidate

- [ ] Create a PR against current master; require the full existing native/SQL/security graph for this shared CI change. Do not mix artifacts from different attempts.
- [ ] Require the actual Intel macOS job to report eight expected cases and zero skips with a source/run/attempt-bound macos.json and SDK identity. Hosted catalog/HEAD200 is readiness evidence only.
- [ ] Require all current PR checks, including real PostgreSQL17.6/Android/macOS, then inspect the tested merge tree and final merge tree before accepting integration.
- [ ] After trusted master includes the fix, dispatch Android Release once with dry_run=true; inspect its complete four-profile gate, skipped publisher and signed artifact source/appID/certificate/checksums. Do not install over the concurrently used Samsung; current phone identity requires a separate fresh guard.

Stop on a real source/test failure and fix the cause within the selected leaf. Keep runner-allocation/download failures classified separately, preserve every original result, and never change skip/required/signing/security rules to force PASS.
