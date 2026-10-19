# POC QA-12: real compatible rollback (#60)

This runner exercises the shipping signed-bundle rollback command on one owned,
empty nested Docker daemon. The fixed `voice-platform` project/volume names and
Linux namespace probes run there. No host Docker socket is mounted, no daemon
TCP port is published, and the final controller starts with only a Unix listener.
The outer daemon must be local (Unix endpoint). Cleanup checks ownership labels
before removing the outer container, image and data volume. Foreign services are
never selected by the shipping project's fixed names on the outer daemon.
Generated work entries return to the caller UID/GID before browser access and
cleanup. Ownership changes exclude the source checkouts and never follow links.
Python bytecode writes are disabled in the container, keeping source checkouts
free of root-owned caches. Failed receipts contain only allowlisted public guard
messages, source frame locations, numeric exit codes and fixed failure flags.

Use a Linux amd64 Docker daemon. On an ARM64 Mac, a separate QEMU x86_64 VM
avoids the observed Go compiler crash under Rosetta and the emulated daemon's
netfilter failure. The shipping server builder emits the required `linux/amd64`
release images. Allow 5 GiB VM memory and free space for the compiler,
two OCI bundles and the deployment's real disk-headroom guards. Only loopback
port 5443 is exposed. The browser maps `qa60.localhost` to loopback. Its local
certificate exception is explicit; internal rollout curl trusts the owned CA.
The existing `PRIVATE_PROXY_IP` and `TRUSTED_PROXY_CIDRS` inputs select
`172.30.254.250/32` for the QA proxy. A negative control confirmed that the
default static `.2` collides with the first dynamic endpoint in an empty bridge.
The retained Compose file and forwarding trust checks remain unchanged.

One explicit fixture dependency is added before LiveKit starts: an owned egress
bridge for its retained `use_external_ip: true` STUN discovery. Actual controls
observed failure without outbound access and successful authenticated RoomService
with this bridge. LiveKit's configuration is unchanged; its management/metrics
ports remain unpublished. API, PostgreSQL and proxy keep their retained networks.
Both the two canonical network identities and this additional fixture identity
must survive the complete rehearsal. This checks rollback on this prepared
instance; fresh production-network provisioning is outside this acceptance.
See the [LiveKit configuration reference](https://github.com/livekit/livekit/blob/master/config-sample.yaml)
for external-IP discovery precedence.

## Inputs and invocation

Provide an observed CI proof JSON with `current` and `previous` entries:
`head` (40-character actual tested revision), `run`, `status=success`, and
`checks.backend|web|contracts` containing the observed numeric job `id` and
`conclusion=success`. Read these from authenticated GitHub Actions results;
do not turn pending, missing or failed results into PASS. Each checkout remains
clean at that exact source revision. Master squash/merge tree equivalence is
recorded separately, never by relabeling an image or a gate receipt.
The reviewed checkout must match retained runtime/release inputs. The sole named
exception is `tools/release/delivery/test_workflows.py`, an inert workflow-policy
unit-test adaptor updated for action pins; other tests and all runtime, toolchain,
archive/signing/install/rollback sources remain bound. The current reviewed harness
and builder execute separately, with their own source hashes and tests.

```sh
python3 -m unittest tools.qa.compatible_rollback.test_evidence \
  tools.qa.compatible_rollback.test_isolation tools.qa.compatible_rollback.test_ci_proof \
  tools.qa.compatible_rollback.test_diagnostics \
  tools.qa.compatible_rollback.test_builder_identity \
  tools.release.rollback.test_rollout tools.build.server.test_smoke_readiness \
  tools.build.server.test_runtime_inputs tools.build.server.test_social_preview \
  tools.build.server.test_image_audio_flag
python3 -m tools.qa.compatible_rollback.run --ci-proof /absolute/path/ci-proof.json
```

Node and locked Playwright/Chromium must already be available in
`clients/web/node_modules`. Docker CLI and Compose come from the pinned controller;
the canonical builder downloads its checksum-pinned Buildx plugin. The selected
pair must contain the existing source and install/rollback inputs.

The `Compatible rollback acceptance` GitHub Actions workflow runs the same
command on native Linux amd64. `ci-inputs.json` selects retained source objects;
`ci_proof` reads their actual completed CI runs and required jobs from GitHub,
checks master tree equivalence, product/release-code currency and schema/topology
compatibility before writing the proof. The producer must be the repository
master push/dispatch CI workflow, or its successful trusted master Build server workflow with a unique
successful bundle job and all three successful qualified receipt gates. Fork
heads, unrelated workflows, untrusted events, incomplete/duplicate/foreign jobs
and docs-only skipped producers cannot attest server quality. The proof records
the actual producer workflow; this does not claim native or physical acceptance.
New input receipts never relabel PR/merge-queue/feature-dispatch results as master
quality, even when product trees look equivalent. Historical isolated POC records
remain tied to their original source/harness and are not rewritten. A missing or unsuccessful gate fails
before building. The workflow retains only sanitized JSON and synthetic PNGs;
private build logs, environment files, session data and signing keys stay private.

The runner builds both releases with the shipping trusted server builder, actual RNNoise
asset compilation, SBOM/provenance, image smoke tests and signatures. A separate
QA public anchor is provisioned before either artifact; the private signing key
is deleted. These are local QA builds, never production releases or new production
trust anchors. Actual successful CI results are copied into source-bound gate
receipts with their run/job provenance. Every bundle is verified before reuse.
Only immutable artifact files and the public QA anchor are retained in ignored
`.out/issue60/bundle-cache` to avoid recompiling for an observer retry. Application
data and volumes are not cached. A different source pair or trusted build-tool
implementation requires a new empty cache directory; an incomplete cache is not
accepted. Both harness and active builder/dependency hashes bind the receipt.

The trusted builder's explicit `--source` selects each clean retained Git root;
the default still builds its own repository. Source archive, labels, compatibility
and gate receipts refer to that selected head. Builder code is independently
recorded from the reviewed QA revision and mounted read-only. The builder now
waits for PostgreSQL TCP readiness: an actual negative control observed the
temporary init server accepting Unix sockets before TCP became available.
Both migration passes and every artifact smoke check still run. The signed
runtime and canonical rollback command are unchanged.

## Observations

1. Start both real images and the retained Compose services with the explicit
   SFU-only fixture egress above; seed two
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
6. Compare the four volume and three observed network identities, logical product data,
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
