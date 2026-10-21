# Hosted server build retry fix — 2026-10-21

Scope: GitHub Actions run `39625644712`, failed bundle job `119327639920`.

The OCI export itself was verified, but the bundle then passed the OCI-layout tar
to `docker image load`; the GitHub-hosted Docker daemon rejected that archive
format. On a rerun of only the failed bundle job, the bundle also looked for
check receipts suffixed with the new `run_attempt`, while successful upstream
jobs had retained receipts from the prior attempt.

The builder now retains the attested OCI archive for verification and exports a
Docker archive from the same Buildx build for `docker image load`. It verifies
that the loaded Docker image ID and root filesystem layers match the verified OCI
config before using that image for smoke tests. Receipt downloads are scoped to
the exact source SHA and workflow run; the collector selects each gate's latest
available attempt and fails closed on foreign, future, malformed or failing
receipts.

Local verification: 74 server-builder tests PASS; 3 OCI verifier tests PASS; 21
master-quality and delivery workflow tests PASS; delivery graph and pinned
Actions checks PASS; reviewed Python selection and auxiliary SDK workflow checks
PASS; changed Python modules compile; `git diff --check` PASS.

NOT_RUN: a live GitHub-hosted multi-export Buildx build and Docker import. The
local Docker daemon was unavailable in this environment. Hosted workflow
acceptance remains pending PR checks; no release-gate PASS or production build
is claimed by this record. The full local Python runner was also attempted, but
host-only tests requiring writes under `~/Applications` and the local Go standard
library did not run successfully in this sandbox; the focused affected suites
above passed.

## Follow-up: Buildx Docker exporter failure

Scope: merged master run `39638849339`, bundle job `119362261267`, source
revision `d10822280eb6b678326758ded34b9a1376e5bad6`.

The hosted runner rejected the combined OCI and Docker outputs with SBOM and
provenance enabled: `docker exporter does not support exporting manifest lists`.
The attested OCI export and receipt collection succeeded; all jobs before the
bundle passed. Docker documents that attestations attach to the image index and
that `--provenance=false --sbom=false` disables them for a Docker-image-store
export ([Build attestations](https://docs.docker.com/build/metadata/attestations/)).

The follow-up keeps the attested OCI build as the source of release verification,
then performs a Docker-archive export with attestations disabled. It reuses the
same pinned source, labels, build arguments and cache import, and still verifies
the loaded Docker image ID and root filesystem against the OCI config before
smoke tests. Cache publication remains tied to successful image verification.

Focused verification: 74 server-builder tests PASS, including the two-export
command contract. NOT_RUN: a hosted Buildx/Docker rerun for this follow-up; the
local Docker daemon is unavailable in this environment.
