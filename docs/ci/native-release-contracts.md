# Native release contracts (#396)

Each platform retains its own runner, build tools and protected signing job.
There is one shared source/asset verifier and immutable GitHub publisher.

| Platform | Stable trigger/source | Version/build | Measured signature | Public assets | Promotion / recovery |
| --- | --- | --- | --- | --- | --- |
| Android | `android-vX.Y.Z` push/tag dispatch, or protected master dispatch whose exact commit has that tag | `client-build.json` + Flutter pubspec; ABI versionCode checks retained | Existing pinned Android release certificate; no new key | Existing three ABI APK names, manifest, SHA256SUMS, RNNoise license/SBOM | Publish immutable tag assets; installed-client/user update path unchanged; no downgrade claim |
| Windows | `windows-vX.Y.Z` push/tag dispatch, or protected master dispatch whose exact commit has that tag | Same client identity and native build | Existing unsigned or measured Authenticode state; no new certificate | Existing ZIP, Setup.exe, full NUPKG, releases.stable.json, manifest, SHA256SUMS | Existing signed updater catalog/promotion remains separate; no automatic promotion or rollback added |
| macOS | Manual matching-tag dispatch, or protected master dispatch whose exact commit has `macos-vX.Y.Z` | Same client identity and native build | Existing ad-hoc signature; notarization NOT_RUN | Existing ZIP, .zip.sha256, manifest, SHA256SUMS; now also the existing manifest-referenced RNNoise license/SBOM | Existing direct distribution/update promotion remains separate; no notarization or installed recovery claim |
| iOS | No repository release workflow/owned `tools/build` or `tools/release` automation found | Separate manual Xcode/App Store Connect process | Existing provisioning/distribution policy untouched | Outside this three-platform contract | Separate scope decision; automated pipeline, physical acceptance and TestFlight publication NOT_RUN |

## Source authority and candidate mode

A stable publish requires the upstream repository, canonical platform/version
tag matching pubspec and client identity, clean tracked source, exact checkout
commit and master ancestry. Checkout fetches complete history. Both lightweight
and annotated tags are peeled to their commit; raw trigger SHA and commit SHA
are separately retained. The publisher also reads the current GitHub tag ref
before writes and before/after final publication, including annotated tags.
Missing or moved tags and foreign commits fail closed. This is not a server-side
policy preventing a repository administrator from later moving/deleting a tag.

All three workflows expose `workflow_dispatch` input `dry_run=true`. Run it from
trusted master or the matching platform tag to build and verify a candidate
without creating a tag, release or upload to GitHub Releases. The canonical tag
string supplies existing package filenames, but a master candidate records
`tag_verified:false`, its real source ref and `release_mode:candidate`.
The publisher independently rejects every candidate contract. A stable dispatch
with `dry_run=false` may use master only when the already-existing canonical
platform/version tag resolves to the exact checkout and raw master trigger SHA.
Missing, different or moved tags fail before toolchain setup/signing. The
contract retains the actual master ref, `workflow_dispatch` event and trigger;
the publisher independently binds those fields to its actual execution before
any API write. It never changes a tag or accepts a candidate as stable. macOS
remains manual-only.

This master dispatch uses the existing `production` environment, reviewer,
master-only deployment rule and shared signing queue. Repository settings stay
unchanged: no new environment, tag allowlist, tag rule or copied secret. With the
current master-only production policy, direct tag jobs remain ineligible for the
protected job; use the existing master workflow-dispatch route after the normal
version/tag preparation and independent production review. A canonical tag at
another commit is not retargeted to make the run pass; publish a new version.

The obsolete feature-branch/retained-run-ID candidate workflow is removed.
The standalone Unicode/extended-path C++ regression and portable recovery
preflight move to the mandatory Windows native-unit job. Full native recovery/GUI
coverage is in the normal Windows DAG
(#391); native signed candidates use the platform workflows above. No old
executable is silently reused by an unversioned fixture lookup.

## Asset integrity and signing boundaries

`python -m tools.release.native_contract.run preflight PLATFORM` records public
source authority before installing SDKs or exposing signing inputs. After the
existing platform build/inspection, `... run assets PLATFORM` requires exact
asset names, non-empty regular files, the 95 MB per-asset ceiling, complete
SHA256SUMS, clean/source/version-bound native manifest, approved toolchains,
contracts and unchanged platform signing model. Android retains its measured
APK/certificate and ABI checks. Windows ZIP inspection verifies the complete
inner manifest/files/checksums without extraction and rejects QA purpose markers,
links, aliases and unsafe paths. The ZIP has bounded entry count/expanded bytes.
The instrumented #391 CI package cannot be passed off as a stable Windows asset.

The full native/installer build paths and public download asset names remain
unchanged. macOS previously published only four of six manifest-referenced files;
the shared asset contract publishes all six. No source `.env`, signing material,
private logs or device data enter these public records. Signing secrets remain
step-scoped in protected native jobs; required CI/branch settings are unchanged.

## Immutable publication, retries and notes

`node tools/release/native_contract/publish.mjs --platform PLATFORM` rechecks the
local source/assets before any API write. It creates a draft at the exact source
SHA, uploads only validated files, verifies the complete remote asset inventory
and SHA256 digests, rechecks the tag, then publishes the draft. API redirects are
refused. Title/notes bind platform, source, native version/build, measured signing
state and manifest digest. macOS notes explicitly say ad-hoc/not notarized.

A lost create response resumes the matching authenticated draft. The published
by-tag endpoint alone is insufficient for recovering drafts; lookup is bounded
to ten 100-row history pages. Lost upload/publish responses are confirmed before
retry; attempts are bounded to three. Foreign bytes/assets/metadata fail without
overwriting/deleting them. A fully published identical release is verified with
GETs only; an incomplete published release is never filled in or replaced.
Older releases lacking this exact source/manifest metadata are not retroactively
edited: publish a new version instead. Rebuilding the same source may produce
different bytes; safe retry requires the exact retained payload, not an assumed
reproducible rebuild. Conflicting drafts require operator diagnosis, not deletion
by the publisher.

Workflow artifacts retain complete assets and separate public source/contract/
publication metadata for 30 days, with SHA/run/attempt-bound names. Contract PASS
means asset verification, not publication: only publication.json PASS records a
verified published release. Dry-run candidates have no passing publication
receipt. Existing updater catalog signatures, promotion and rollback contracts
are not changed by a GitHub Release publication.

Focused checks:

```sh
python3 -m unittest tools.release.native_contract.test_source tools.release.native_contract.test_assets tools.release.native_contract.test_workflow
node --test tools/release/native_contract/publish.test.mjs
```

Tests use real local Git/tag ancestry, actual archive/hash inspection and a
synthetic HTTP transport with bounded retry/conflict cases. Synthetic PE/APK/ZIP
bytes are never executed and are not native distribution evidence. New Android,
Windows and macOS candidate builds on their actual runners, API publication and
physical/client-updater acceptance remain NOT_RUN for this change, deferred to
combined epic validation per owner.

API references: [GitHub Releases](https://docs.github.com/en/rest/releases/releases)
and [Git references](https://docs.github.com/en/rest/git/refs). Draft-first is an
application rule; repository immutable-release settings are not changed here.
