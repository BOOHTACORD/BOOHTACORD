# Trusted server installation (#395)

Status: implementation candidate; isolated real-stack and delivery acceptance are
not complete. This document does not authorize a production rollback or assert
that GitHub environment reviewers are configured. External protection work is #386;
the owner manages the required master status check in #385.

Automatic `Deploy production` and manual `Install retained release` use
`.github/actions/install-trusted-server`. Their event/run/revision bindings remain
separate and validated. Only a successful protected master `Build server` run from
this repository can supply a bundle. The selected artifact ID, run, attempt, source,
name, size and digest are checked before download and again after download.
The actual downloaded ZIP must match its recorded size and SHA-256. Older retained
artifacts without an API digest are explicitly marked as legacy; the exact selected
artifact ID, transport checksum and provisioned host signature are still required.
Only the two expected regular transport files can be extracted.

The current protected controller remains checked out at `GITHUB_SHA`; installation
does not execute historical delivery code. Its clean tracked tree and source
ancestry are checked, and its installer archive is independently SHA-256 checked
over pinned SSH. The signed bundle continues to identify the application source.
No application image is rebuilt during installation. Host-provisioned public trust,
signed manifests, append-only migration compatibility, immutable retained releases,
expected running source and the shared host installation lock remain mandatory.

The read-only automatic route has no production queue or credentials. Only its
qualified install job holds `v-bootybay-production`; manual recovery and compatible
rollback retain the same non-cancellable group at workflow scope. This uses the
classic single pending slot and does not promise FIFO or preservation of every
pending release. The workflow's production environment admission does not by
itself prove that a human reviewer approved it; receipts say `NOT_ASSERTED`.

Transport stages have separate finite limits: current-source observation 45 s,
forward-history check 10 s, bundle SCP 300 s, driver SCP 60 s, remote installation
600 s and fresh readback 45 s. Metadata/download operations also have fixed
limits, and both callers have a 30-minute job ceiling. SSH uses strict pinned host
verification, batch mode, one connection attempt and bounded connection/liveness
settings. Each attempt uses a private random staging directory, avoiding partial
transport collisions between retries of the same source. Only acknowledged
transport copies are removed; retained releases and persistent volumes remain.

A separate SSH readback must acknowledge the fresh random nonce and controller,
application source, API/Web image digests and revision labels, HTTPS health, four
persistent-volume identity hashes and the actual PostgreSQL schema fingerprint.
The schema query reads system catalogs in a read-only transaction and returns only
a SHA-256 hash. It does not export product rows, credentials, attachment contents,
TLS keys or database copies. An unchanged signed migration inventory cannot explain
a changed schema fingerprint. The fresh observation must match the recorded
post-install state; HTTP 200 alone cannot acknowledge installation.

The 30-day `delivery-RUN-ATTEMPT` artifact contains one bounded sanitized receipt.
Missing, failed or skipped stages cannot produce PASS. Timeout/interruption means
remote completion is UNKNOWN; killing the local SSH process does not prove that
remote Docker work stopped. Do not blindly rerun or roll back after such a result.
The verified current driver invokes the canonical installer in the foreground
with HUP ignored and inherited by its rollout children. Installer stdout/stderr
go to a mode-0600 file inside the existing private driver directory, so a closed
SSH pipe cannot abort maintenance cleanup. The wrapper waits for the real exit
status before its EXIT trap removes that directory; no alternate installer,
background success, released host lock or synthetic acknowledgement is added.
Interruption still fails the client receipt. Recovery requires independent idle
lock, maintenance-off and fresh health/state checks; this protection does not
turn a lost connection into confirmed success or ignore administrator SIGTERM.
New signed runtimes also emit ten ordered Unix-second markers for admission,
migration, services, health and rollout completion. Their intervals are recomputed
from those exact events; partial, reordered or inconsistent reports fail closed.
The active-maintenance interval is bounded by observed enable/disable completion;
a separate request-to-disable interval includes the enable command. Precision is
one second. Old signed runtimes without markers are `NOT_AVAILABLE_LEGACY`, with
no inferred maintenance duration. Actual before/after real-stack measurements
remain acceptance work.

Remaining #395 acceptance: controlled actual artifact download, mixed-scope queue
serialization, two consecutive signed real-stack releases, same-SHA retry and
immutable mismatch, interrupted/failed SSH and health, volume/ACL continuity,
explicitly approved schema-compatible rollback, and before/after phase and
maintenance measurements. Local tests cannot close that gate. No database rollback,
backup, snapshot, credential export or production rollback is added.
