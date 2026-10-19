# Artifact policy (#387 / CICD-18) — proposal

Status: local implementation on top of #393, not published or accepted. #387
remains open. Local workflows now use the policy; live retention is unchanged.

Pure retention/naming functions and their eight focused tests are implemented
locally. Their initial missing-module failures preceded implementation; actual
hosted adoption, artifact privacy review and measured acceptance are pending.

A local capture-package prototype additionally stores identical PNG/JSON bytes
once while retaining every logical path and exact checksum. Verification and
restore check full execution identity and portability before writing. Its
`integrity` result is a storage check, never a test/release verdict. Local tests
and real downloaded-data roundtrips are recorded separately in
`evidence/ci/artifact-capture-package-local-2026-10-19.md`. Local runtime and
workflow checks are recorded in `evidence/ci/artifact-runtime-local-2026-10-19.md`;
hosted verification and source/fixture privacy review remain required.

Release receipts/bundles, native packages and actual acceptance/QA proof retain
the existing 30 days. Failed/cancelled/unknown runs keep 30-day diagnostics.
Only synthetic captures from a successful ordinary PR job may use 7 days for
review; merge queue, master, tags and manual QA retain 30. This separates review
captures from retained install/rollback and physical acceptance evidence.

The standalone R14 navigation upload duplicates a file already required inside
the full 34-frame Flutter capture archive. The proposed consolidation preserves
that file, full checksums and all required frames in the one archive. Legacy
shadow controls and pinned historical native fixture names stay unchanged.
Windows outputs need source/run/attempt names to avoid collisions on retry;
native package formats and public GitHub Release asset names remain unchanged.

Download a ZIP through GitHub Actions, record its artifact ID, repository/run
ownership, API `size_in_bytes` and `digest`, and independently obtain the tested
checkout source and namespace/profile. A PR run's head SHA may differ from its
tested merge checkout. Never infer the expected identity from the downloaded
manifest itself. Verify and restore with public values:

```sh
python3 -m tools.ci.artifact_policy.inspect \
  --archive /absolute/path/captures.zip --sha256 API_ZIP_SHA256 --bytes API_ZIP_BYTES \
  --source-revision TESTED_CHECKOUT_SHA --run-id RUN_ID --run-attempt ATTEMPT \
  --namespace web --component web --profile browser-shell --platform linux \
  --output /absolute/new/package --restore /absolute/new/original-paths
```

The CLI does not execute HTML/scripts, overwrite existing directories or follow
linked parents. It verifies ZIP bytes, bounded members, exact identity and every
payload before restoring PNG/JSON files. It proves storage integrity, not a test
verdict, production release authority or universal pixel privacy. Network/API
ownership verification is the caller's separate prerequisite.

Next: source and privacy review, actual current
after-#393 baseline per PR/master/tag/QA,
matched before/after count/bytes/occupancy, actual artifact download and identity
verification, and documented acceptance paths. Initial pre-#393 inventories are
only prerequisite observations and must not be attributed to this policy change.
