# Trusted server build cache (#394)

The protected master builder uses its own private
`$HOME/.cache/boohtacord-server-buildx-v1`. Other builders keep the uncached export
path unless explicitly configured. No GitHub cache is restored into this directory.
No production-host build, signer key, SSH key or deployment environment enters it.

Each API/Web namespace hashes the exact toolchain policy, Dockerfile and Go/npm
dependency locks. The source revision is deliberately separate: every image still
gets its exact revision/archive labels, provenance and SBOM, and both actual OCI
archives are verified after every build. Cache admission grants no quality status.
Real image smoke, strict source-bound gate receipts, manifest signing, immutable
packaging and the release checksum remain mandatory. The public download bundle
still contains exactly the original two transport files.

The cache root requires the current POSIX owner, mode0700, a fixed owner marker and
an exclusive process lease. Imports pin an explicit cache manifest digest. Before
reuse, every blob's actual SHA-256, single-link regular-file identity, OCI layout,
index and namespace are checked. Corruption or namespace mismatch triggers a cold
build; foreign roots/links/unknown root entries fail rather than being deleted.

API and Web export into fresh staging directories. Only a verified source-bound
OCI build and a validated cache export can replace that service's prior generation.
At most one accepted generation per service is retained, capped at4GiB each;
staging is removed on exit and abandoned staging is removed under the next lease.
Export requires a4GiB allowance plus2GiB free-space reserve. This is a retained
cache limit and preflight reserve, not a filesystem write quota. No global Docker
prune or background cleanup job is added. A cancelled build may lose warm cache
state; it cannot supply release checks or skip the next build/smoke/signature.

Go module/compiler and npm download mounts use the dependency namespace and
`sharing=locked` on the trusted builder. Each bundle now uses a separate
`docker-container` BuildKit worker pinned by immutable image digest in
`tools/build/server/buildkit-image.json`. The exported API/Web cache is the
persistent warm input; the worker's internal state volume is removed after the
build. The pin and actual trusted builder toolchains participate in cache identity,
including when building a retained product revision that predates the pin file.
The macOS/Android/Flutter version policy is unchanged. Web's dependency layer still
runs before changing release arguments, so a new SHA alone does not invalidate
`npm ci`.

Pinned Buildx0.37.1 supports local cache `reset=true`; the fixed cache tag is
`boohtacord-master-v1`, and export uses `mode=max`. See Docker's
[local cache reference](https://docs.docker.com/build/cache/backends/local/) and
[cache backend requirements](https://docs.docker.com/build/cache/backends/).
The existing Docker containerd image store is still required. The worker exports
OCI first; a bounded archive-shape check and the full original source/SBOM/
provenance verifier run before `docker image load`. The loaded image identity is
then verified against the same OCI index before smoke or cache publication.
The Docker archive exporter is not used, so attestations are retained.

## Owned storage and interrupted builds

`$HOME/.cache/boohtacord-builder-storage-v1` contains a private mode0700 ownership
marker, exclusive controller lease and atomic/fsynced mode0600 active journal.
The journal is written before resource creation. It binds a random owner, exact
source/archive, pinned worker image and daemon identity. An existing target image
tag blocks the build; it is never overwritten. Same-source delivery retries use
their verified immutable producer rather than rebuilding over its local tag.

The state volume and API/Web image configs carry the owner label. Disposable
smoke containers/networks also carry a separate `smoke` scope, and smoke commands
use the exact same private Docker client environment as the image builder. Smoke
PostgreSQL stores its fixture data in tmpfs. The enclosing owner performs checked
teardown before the bundle can report PASS, including a resource whose creation
response was lost when the controller stopped.

Cleanup first checks ownership, worker image/mounts, source/archive image labels,
allowed image references, non-privileged/no-volume-or-bind smoke containers and
the complete set of network/image users. A foreign alias, network attachment,
container user or changed owner blocks deletion. Only those checked containers,
networks, the one worker state volume and new owned images are removed. Existing
images and other projects remain untouched; no global prune is performed.

SIGTERM/ordinary exceptions attempt cleanup. SIGKILL cannot run a finalizer:
the durable journal remains, and the next exclusive controller must validate and
reclaim that exact orphan before starting. A corrupt journal, different daemon
or incomplete cleanup fails closed and preserves the journal for investigation.
Metrics cannot PASS while cleanup is missing, failed or still running.

If the initial Docker metadata preflight fails before this controller acquires
resources and its exclusive lease has no active journal, it releases the lease
without repeating the failed Docker probe. The build remains FAIL and no
`filesystem_after` measurement is invented. An existing orphan journal still
blocks this path and is preserved without unverified Docker mutations.
Docker command failures report only finite operation/reason categories (for
example `daemon_info`/`timeout`) in `setup_failure` or `cleanup_failure`; command
arguments, paths, stdout, stderr and raw exception text are excluded. An actual
cleanup or its final verification failure remains fatal.

The worker has an 8GiB GC target and 2GiB minimum-free target. These are GC targets,
not filesystem write quotas; in-use data can temporarily exceed them. A 14GiB
free-space preflight reserves room for a fresh worker, one cache export and the
existing reserve; capacity is remeasured after orphan recovery. Public metrics
retain filesystem used/available bytes, image counts, the daemon hash and exact
cleanup counts/timings. They omit Docker paths, references from other projects,
private command output and credentials. Filesystem figures describe the mount
containing Docker's data root, not a measured byte total of that directory;
containerd blob reclamation may lag metadata removal. The pinned worker tool image
is intentionally retained for subsequent starts.

The dedicated worker/state behavior is described in Docker's
[container-driver documentation](https://docs.docker.com/build/builders/drivers/docker-container/).
This change does not declare a hard cap on the entire shared Docker data root.

`<revision>.build.json` records actual monotonic archive/extract/assets/plugin,
per-image build/export/verification/cache, smoke, runtime, manifest, signature and
packaging durations. Import status `WARM_VERIFIED` means cache was supplied; it
does not assert a BuildKit layer hit. Failed/interrupted measured operations cannot
finish with PASS, and exception text or build output is never included. Upload
duration belongs to the GitHub upload step timestamps. A separate attempt-bound
30-day metrics artifact keeps this report out of the signed transport pair.

Implementation checks include focused ownership, corrupt-journal, foreign-use,
interruption, immutable-import and metrics regressions. The previous full-bundle
cold/warm measurements in `evidence/ci/server-build-cache-2026-10-19.md` concern
the former Docker-driver backend. Local tiny-OCI protocol checks are separate;
they do not certify application smoke, native x64 shipping performance or signing.
New full-bundle cold/warm and disk/cleanup acceptance on the protected trusted
builder remain required for #394. No p50/p95, cost or disk-growth win is inferred
from fixture timings or cache flags.
