# Update Catalog Availability Implementation Plan

> **For agentic workers:** Execute inline under the current root-authorized team packet. Root owns Git, PR, CI, merge and deployment; this worker writes only the selected catalog permission leaf, its tests and this plan. No subagent dispatch or production mutation.

**Goal:** Keep signed public client-catalog data readable by the nonroot API without changing release targets, private installer permissions or validation policy.

**Architecture:** The private installer keeps umask077. After signed runtime validation, environment preparation normalizes only the canonical public catalog directory/file to0755/0644; absent legacy catalog payloads remain compatible. Atomic catalog publication preserves0644 before replacement. No catalog content, selector, URL validation or release-order policy changes.

**Tech Stack:** Python3.12, existing signed-runtime archive/installer, Go1.26.4 catalog store, one disposable Linux container.

## Evidence and boundary

Fresh Windows/x64 and Android/arm64 public selectors return503/no-store with error `client update catalog unavailable` on29Oct04:55:26UTC. Source `Catalog.Select` returns unconfigured/true for absent selectors, while `Store.Policy` returns false only before a valid snapshot; invalid reload preserves lastgood. Production mount permissions/source remain UNOBSERVED. The predicted chain is installer umask077 -> extracted directory0700 -> directory bindmount -> nonroot API cannot read. An official atomic publisher also creates0600 temporary files.

### Task1: Focused RED before implementation

**Files:** Create `tools/release/install/public_catalog/test_prepare.py`; create `tools/release/client_updates/test_permissions.py`.

- [ ] Build an actual minimal tar with `deploy/client-updates/catalog.json`, extract under umask077, then invoke existing `prepare_environment`. Assert public directory0755/file0644, unchanged payload, `.env`0600 and unchanged private parent modes. Before the fix this must fail on directory0700.
- [ ] Cover reused destination repair, absent legacy catalog, missing/irregular payload and actual symlink boundaries. Preserve all unrelated files.
- [ ] Call existing `catalog.mutate` under umask077; assert replaced public file0644, revision increments exactly1, previous r61 is never replaced by r52, nonselected entries unchanged and publisher lock stays private. Before the fix Linux replacement is0600.
- [ ] In exactly one owned Linux container, run `python -m unittest tools.release.install.public_catalog.test_prepare tools.release.client_updates.test_permissions -v`. Retain RED output under Q `.out/fix598-249-ci/catalog/`. Separately read the extracted mount-root as uid65532 to prove permission refusal; do not contact production or Q services.

### Task2: Normalize only verified public payload access

**Files:** Create `tools/release/install/public_catalog/prepare.py`; modify `tools/release/install/runtime.py`.

- [ ] Implement this helper, invoked at the start of `prepare_environment` after its existing production-environment guard. Installer already reaches this edge after signed runtime verification for both new and retained destinations.

```python
from pathlib import Path
from tools.release.bundle.manifest import require

def prepare(directory):
    root = Path(directory)
    require(not root.is_symlink() and root.is_dir(), 'Invalid retained release directory')
    parent = root / 'deploy'
    if not parent.exists() and not parent.is_symlink():
        return
    require(not parent.is_symlink() and parent.is_dir(), 'Invalid public catalog parent')
    public = parent / 'client-updates'
    if not public.exists() and not public.is_symlink():
        return
    catalog = public / 'catalog.json'
    require(not public.is_symlink() and public.is_dir(), 'Invalid public catalog directory')
    require(not catalog.is_symlink() and catalog.is_file(), 'Invalid public catalog file')
    require(catalog.resolve().is_relative_to(root.resolve()) and catalog.stat().st_nlink == 1,
            'Public catalog escaped release or has aliases')
    public.chmod(0o755)
    catalog.chmod(0o644)
```

- [ ] Import helper as `prepare_public_catalog`, then call `prepare_public_catalog(directory)` without changing private umask, archive extraction, `.env` source or release contents.
- [ ] Inside the existing catalog publisher's temporary-file block, after flush and before fsync/replace, add `os.chmod(stream.name, 0o644)`. Leave validation, lock, revision and atomic replace unchanged.
- [ ] Never edit `deploy/client-updates/catalog.json`; retain source revision29 as historical source data and do not substitute it for any running newer target.

### Task3: GREEN and preservation

**Files:** Existing `tools/release/install/test_runtime.py`, `tools/release/client_updates/test_catalog.py`, Go catalog tests; new tests above.

- [ ] Rerun focused Linux tests, then closest installer/runtime and publisher tests in the same disposable container. Require0skips/failures; verify actual uid65532 read succeeds after repair and after atomic publication while private control remains denied.
- [ ] Run `C:/Program Files/Go/bin/go.exe test -json -count=1 ./internal/client_updates/catalog` from W/backend: startup unavailable, reload lastgood, invalid data/revision rollback/reuse, selector and no-store contracts must remain intact.
- [ ] Retain commands/image digest/source hashes and RED/GREEN outputs; remove only the disposable container. Inspect source diff/line counts and give root exact changes. Root commits, opens/reviews PR, obtains current-head CI, merges and follows approved Build server -> signed bundle -> Deploy production -> readback -> exact public GET chain.
- [ ] Verify both native archive edges select the entire `tools/release/install` subtree: `tools.build.server.inputs.RUNTIME_PATHS` for signed runtime and `tools.release.delivery.transfer.DRIVER_PATHS` for the current controller. Add `RuntimeInputsTests.test_public_catalog_helper_is_in_runtime_and_current_controller_archives`; run `python -m unittest tools.build.server.test_runtime_inputs -v`. No packaging/security allowlist change is needed.
- [ ] Add an unconditional focused hosted step for both permission test modules in `.github/workflows/ci-contracts.yaml`. That workflow runs explicit modules; the separate native contract CLI's recursive discovery alone is not proof of hosted execution. Keep all existing commands/jobs/pins/permissions unchanged.
- [ ] Production cause remains predicted until approved read-only metadata confirms it. HTTP200/current identity after deployment is separate evidence; no manual host edit, source-catalog substitution, stale r61→r52 promotion, other-entry mutation or physical updater acceptance.
