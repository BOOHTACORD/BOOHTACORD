# Dependency-aware routing (CICD-02, #384)

`tools/ci/select_changes/dependencies.json` is the versioned, ordered ownership map.
The **first matching rule for each path** contributes gates and independent server/
native release impact. The union covers every changed path. Unknown ownership,
unavailable diff, invalid base, invalid event or checkout mismatch selects all gates
and both release impacts. Malformed dependency maps fail the selector itself.
`contracts` is always selected, including a proven empty diff.

The same module/command serves `ci.yaml` and `build-server.yaml`. There is no separate
server `paths` filter (including GitHub's truncated server-side path list). Every
master push runs a small hosted selector; costly receipt gates and the signer run
only on server release impact. Explicit master dispatch conservatively selects all.
The exported `server` remains an alias for compatibility; new explicit outputs are
`server_release_impact`, `native_release_impact`, `map_version`, `map_sha256` and
`uncertain`. Native release workflows retain their own unconditional quality/signing
contracts; impact classification does not itself publish a native release.

| Path class | PR gates (contracts always) | Server / native impact |
| --- | --- | --- |
| Docs, ordinary evidence, backlog | contracts | no / no |
| Backend | contracts, backend | yes / no |
| Web, Web builder | contracts, web | yes / no |
| Flutter, native builders, desktop updater publishing | contracts, Flutter, Windows | no / yes |
| Shared RNNoise source | contracts, Web, Flutter, Windows | yes / yes |
| Shared audio tools / bundle / archive / native artifact code | all | yes / yes |
| Contracts / workflow / toolchain / CI / verification policy | all | yes / yes |
| Deployment / server release tooling | contracts, backend, Web | yes / no |
| LiveKit network configuration evidence JSON | contracts, backend, Web | yes / no |
| Unknown path, unknown diff, tag/manual event | all | yes / yes |
| Proven empty diff | contracts | no / no |

PR diffs use the validated event base and Git merge-base against the actual tested
checkout. Synthetic merge checkouts include the complete feature change without
counting unrelated base history. Pushes compare exact `before` against checkout,
including force-push removal. First push/missing history fails closed. `--no-renames`
and NUL-separated output retain both ownership sides of moves/deletes and do not
interpret filenames or event values as shell source. No changed filenames are logged.

## Non-release completion is not a deployable artifact

A successful Build server can now intentionally skip backend/web/contracts/bundle.
The hosted, read-only `route` job in Deploy first verifies the same repository,
master branch, allowed producer workflow/event and successful completed run. It
reads every latest job page and rejects missing/duplicate/foreign/failed/cancelled
jobs. Only these two shapes are accepted:

- `bundle` and all three receipt gates succeeded: proceed to protected install.
- `changes` succeeded and bundle plus all three gates explicitly skipped: no install.

A selector failure, arbitrary missing bundle or partial receipt set cannot become
a successful no-release decision. Legacy successful producers without the new
selector remain installable; legacy skipped producers are rejected.
The route job receives only a read-scoped Actions token on a hosted runner. It does
not enter the production environment or access signing/SSH credentials. Only the
existing install job enters production, after `has_bundle=true`; it repeats producer
provenance and retains exact-SHA checkout, immutable artifact verification, SSH host
pinning, non-cancellable production concurrency, signed bundle and compatibility
guards. No receipt is reused for a different SHA and no deployment lock is removed.

```sh
python3 -m unittest tools.ci.select_changes.test_selection tools.ci.select_changes.test_routing tools.ci.select_changes.test_diff tools.release.delivery.test_routing tools.release.delivery.test_provenance tools.release.delivery.test_workflows tools.verify.workflows.test_selection
python3 -m tools.verify.workflows.selection
python3 -m tools.verify.workflows.delivery
```

Tests create owned temporary Git repositories for actual merge, force-push, rename,
delete, malformed/missing base and shell-like input cases. They cover dependency
classes, independent release impacts, conservative unknown fallback and producer
job/provenance trust failures. Workflow policy checks reject divergent path filters,
missing receipt dependencies, install bypasses or production/write credentials on
the read-only route job. This change does not establish the required aggregate
check policy (#385), optimize suites, or change production approval settings.
