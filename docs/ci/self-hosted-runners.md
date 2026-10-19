# Hetzner Linux CI pool

The Linux workflow targets are disposable LXD guests on the existing Hetzner
host, 167.233.56.32. Windows and Apple native jobs retain their matching hosted
OS and architecture. GitHub-managed Dependabot and automatic Pages jobs are
outside these repository workflow files.

| Slots | Requested labels | Limit per guest | Work |
| --- | --- | --- | --- |
| 1, 2 | `self-hosted, linux, x64, boohtacord-ci-ephemeral` | 3 vCPU, 4 GiB RAM | Tests, browser/SFU fixtures, Android packaging, operational jobs |
| 3, 4 | `self-hosted, linux, x64, boohtacord-ci-meta` | 1 vCPU, 512 MiB RAM | Top-level selectors, required aggregates, deployment route |

The two heavy slots and two small slots consume at most 9 GiB RAM and eight CPU
placements. This is a bounded concurrency configuration on one shared host,
not a capacity or performance claim. Existing DB/Web runners are preserved;
the signing builder keeps its dedicated `boohtacord-builder` label and trusted
source/environment gates. The DB runner's shared database label is not copied.

## Lifecycle and credentials

Root-owned `/opt/boohtacord-ci/controller/worker.py` runs as the four
`boohtacord-ci@N` systemd services. It obtains a fresh repository-scoped JIT
runner configuration through the explicitly authorized GitHub CLI session.
The CLI account configuration stays under root's private directory on the
host, outside every guest. The host API controller never checks out or runs
PR code. No registration or account token is stored in this repository.

Each cycle clones the stopped clean `boohtacord-ci-base`, registers a unique
one-job runner, starts it, then destroys the guest and removes that runner
registration. Failed execution and graceful shutdown also attempt cleanup.
The agent runs as its own guest systemd service, with the runner user's Docker
group and explicit public SDK environment. Short LXD exec calls only inspect
that service; no long-lived exec connection owns the runner process. Healthy
cycles create a new guest after two seconds; a failed controller retries after 30 seconds.
After six idle hours the controller first retires the registration through
GitHub, which refuses removal of a busy runner. Only a successful retirement
allows idle teardown. A refusal or unavailable API grants one bounded six-hour
execution window, so a job assigned near the idle deadline is not cut short.
Host free disk below 5 GiB or CI pool free space below 2 GiB blocks another
cycle. A service must not be changed to persistent workspace reuse.

The base is Ubuntu 24.04, with the official GitHub runner 2.338.0 archive
verified by SHA-256, private nested Docker, PostgreSQL client, native build
dependencies, Android 36/build-tools 36.0.0/NDK 28.2.13676358/CMake 3.22.1, and
the existing PowerShell 7.6.6 SDK. Existing owner-accepted Android license
markers were reused. Workflows still select and verify the exact public
Python/Go/Node/Java/Flutter SDK versions from the repository toolchain policy.
No dependency cache may suppress the original checks or locked installs.
The guest's user Gradle profile caps its heap at 2 GiB, Kotlin at 512 MiB and
parallel workers at two, instead of the app template's 8 GiB local heap.
This profile is outside the checkout and leaves local developer settings intact.

## Isolation

Guests are unprivileged, have separate UID maps, and receive only a root disk
from the dedicated `boohtacord-ci` Btrfs pool and a NIC on `boohtaci0`.
There are no host filesystem mounts, host Docker socket, SSH agent, account
credential directory, production database or signing key in the base image.
Docker, test databases, published test ports and workspaces belong to each
guest. Port 5432 in one guest does not compete with another guest or the host.
The pool is capped at 20 GiB, with each guest root capped at 16 GiB.

The network ACL rejects host 167.233.56.32, private/link-local/metadata ranges
and unsolicited ingress. DNS to the guest bridge and public HTTP/HTTPS are
allowed; SSH egress is restricted to the existing production installer host
176.108.242.211. Guest root is not host root. These are containers sharing the
host kernel, not hardware-isolated VMs. GitHub environment approval/ref rules,
read-only PR tokens and source guards remain necessary. Labels alone never
authorize a signing or production operation.

Shadow measurement accepts old hosted records for historical replay or complete
new heavy-pool records. Mixing these machine cohorts in one comparison fails.
New capture/QA/diagnostic execution may use the marked disposable pool; an
arbitrary persistent self-hosted runtime still cannot publish that evidence.

## Operations and acceptance

Inspect `systemctl status 'boohtacord-ci@*'`, `lxc list` and repository Actions
runner metadata. Stop a slot with `systemctl stop boohtacord-ci@N`; keep the
base stopped. A running slot name changes after each job by design.
Updating/rebuilding the base requires stopping all four services first and
repeating network, Docker, toolchain and lifecycle acceptance.

`self-hosted-proof.yaml` runs two PostgreSQL-service probes plus two bounded
metadata probes. Observe successful jobs on distinct registered runner IDs,
then observe their removal and replacement by fresh IDs/guests. This is the
rollout gate; unit tests or online registrations alone do not prove it.
