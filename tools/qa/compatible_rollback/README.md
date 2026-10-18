# POC QA-12: real compatible rollback (#60)

This runner exercises the shipping signed-bundle rollback command on one owned,
empty nested Docker daemon. The fixed `voice-platform` project/volume names and
Linux namespace probes run there. No host Docker socket is mounted, no daemon
TCP port is published, and the final controller starts with only a Unix listener.
The outer daemon must be local (Unix endpoint). Cleanup checks ownership labels
before removing the outer container, image and data volume. Foreign services are
never selected by the shipping project's fixed names on the outer daemon.

Use a Linux amd64 Docker daemon. On an ARM64 Mac, a separate QEMU x86_64 VM
avoids the observed Go compiler crash under Rosetta and the emulated daemon's
netfilter failure. The unchanged server builder emits the required `linux/amd64`
release images. Allow 5 GiB VM memory and free space for the compiler,
two OCI bundles and the deployment's real disk-headroom guards. Only loopback
port 5443 is exposed. The browser maps `qa60.localhost` to loopback. Its local
certificate exception is explicit; internal rollout curl trusts the owned CA.

## Inputs and invocation

Provide an observed CI proof JSON with `current` and `previous` entries:
`head` (40-character actual tested revision), `run`, `status=success`, and
`checks.backend|web|contracts` containing the observed numeric job `id` and
`conclusion=success`. Read these from authenticated GitHub Actions results;
do not turn pending, missing or failed results into PASS. Each checkout remains
clean at that exact source revision. Master squash/merge tree equivalence is
recorded separately, never by relabeling an image or a gate receipt.

```sh
python3 -m unittest tools.qa.compatible_rollback.test_evidence \
  tools.qa.compatible_rollback.test_isolation tools.qa.compatible_rollback.test_ci_proof \
  tools.release.rollback.test_rollout
python3 -m tools.qa.compatible_rollback.run --ci-proof /absolute/path/ci-proof.json
```

Node and locked Playwright/Chromium must already be available in
`clients/web/node_modules`. Docker CLI and Compose come from the pinned controller;
the canonical builder downloads its checksum-pinned Buildx plugin. The selected
pair must contain those existing builder/install/rollback modules.

The `Compatible rollback acceptance` GitHub Actions workflow runs the same
command on native Linux amd64. `ci-inputs.json` selects retained source objects;
`ci_proof` reads their actual completed CI runs and required jobs from GitHub,
checks master tree equivalence, product/release-code currency and schema/topology
compatibility before writing the proof. A missing or unsuccessful gate fails
before building. The workflow retains only sanitized JSON and synthetic PNGs;
private build logs, environment files, session data and signing keys stay private.

The runner builds both releases with the existing server builder, actual RNNoise
asset compilation, SBOM/provenance, image smoke tests and signatures. A separate
QA public anchor is provisioned before either artifact; the private signing key
is deleted. These are local QA builds, never production releases or new production
trust anchors. Actual successful CI results are copied into source-bound gate
receipts with their run/job provenance. Every bundle is verified before reuse.
Only immutable artifact files and the public QA anchor are retained in ignored
`.out/issue60/bundle-cache` to avoid recompiling for an observer retry. Application
data and volumes are not cached. A different source pair requires a new empty
cache directory; an incomplete cache is not accepted.

## Observations

1. Start both real images and the exact retained Compose topology; seed two
   ordinary users plus an admin, TEXT/DM messages and actual uploaded attachments.
2. Read current image refs/IDs, live logical schema, persistent resource identity
   and committed data/file fingerprints. Call the canonical read-only preflight
   and assert that these observations do not change.
3. Two independent authenticated browsers prove valid new lease admission (201)
   before maintenance. Run the unchanged `tools.release.rollback.run --rehearse`
   with a 90-second previous-release observation window.
4. In both shipping 15-second maintenance warnings, both browsers must see the
   actual SSE-driven banner and receive 503/MAINTENANCE for the same previously
   valid admission request. No routed responses, fake Docker, monkeypatches or
   substituted transition code are used.
5. On the previous release and again after restoration, verify actual running
   digest-qualified refs and revision labels. Reload both clients, confirm their
   original accounts, TEXT and DM contents, exact downloaded attachment hashes,
   source receipt and successful new admission. Retain all ten browser captures.
6. Compare the four volume and two network identities, logical product data,
   attachment files, persisted TLS material, proxy config and actual logical DDL.
   These are read-only fingerprints, not copied data or restore points. Volatile
   session/read-cursor/lease/worker timestamps and PostgreSQL WAL bytes naturally
   change; they are not presented as unchanged physical database files.

The strict receipt guard requires all five phases, both browsers, positive and
negative admission controls, signed compatible bundles and unchanged storage.
Missing/duplicate observations, drift, mutable image tags and extra secret-bearing
row fields fail. Source hashes bind the accepted run to the actual harness.

Reports and synthetic PNGs are ignored under `.out/issue60/runtime`. Review PNGs
at original resolution before publishing evidence. Passwords, cookies, account/
lease identifiers and message/attachment contents are absent from public JSON.
Private inputs and live services are removed even on failure. This is an isolated
live rehearsal; it does not perform or claim a production maintenance window,
physical media quality or a deployment capacity result.
