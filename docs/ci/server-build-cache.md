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
`sharing=locked` on the trusted builder. They remain BuildKit-managed internal
caches, separate from the bounded exported directories. Normal Docker/BuildKit
host GC still governs those existing internal stores; this change makes no claim
to cap the entire Docker data root. Web's dependency layer runs before changing
release arguments, so a new SHA alone no longer invalidates `npm ci`.

Pinned Buildx0.37.1 supports local cache `reset=true`; the fixed cache tag is
`boohtacord-master-v1`, and export uses `mode=max`. See Docker's
[local cache reference](https://docs.docker.com/build/cache/backends/local/) and
[cache backend requirements](https://docs.docker.com/build/cache/backends/).
The existing containerd image store is still required for the Docker driver.

`<revision>.build.json` records actual monotonic archive/extract/assets/plugin,
per-image build/export/verification/cache, smoke, runtime, manifest, signature and
packaging durations. Import status `WARM_VERIFIED` means cache was supplied; it
does not assert a BuildKit layer hit. Failed/interrupted measured operations cannot
finish with PASS, and exception text or build output is never included. Upload
duration belongs to the GitHub upload step timestamps. A separate attempt-bound
30-day metrics artifact keeps this report out of the signed transport pair.

Implementation checks are focused regressions and workflow validation. Cold/warm
full-bundle measurements and an actual speedup remain unproven until the later
combined acceptance requested by the owner. No p50/p95 or disk-growth improvement
is inferred from unit tests or cache flags.
