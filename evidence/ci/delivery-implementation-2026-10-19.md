# CICD-11 / #395 common delivery candidate — 2026-10-19

Outcome: LOCAL_CANDIDATE, runtime acceptance NOT_RUN. Parent #382 remains open,
7/20 leaves complete. Base master 8547b88e490efcefc7dc8d49f14dd88e7bf453ed;
queue-boundary local checkpoint 1a1d0207efa7138d5d3cb63409e32e4380c663d6.

Both protected callers now share one composite installation action. Controller
and automatic/manual event bindings are validated before producer metadata. The
same immutable producer/artifact authority is validated before and after download.
Actual ZIP bytes/digest and exact safe transport pair are checked before SSH key
configuration. API authorization is never forwarded to blob URLs or redirects.
Retained legacy metadata without an outer digest remains explicitly classified.

The current protected controller supplies the installer; the signed bundle supplies
the target application source. Source ancestry, checksum/signature, immutable
release, expected-current, compatibility, disk/headroom, single attachment writer,
maintenance, private media path and proxy-network guards remain. Private per-attempt
staging prevents same-source SCP partial-file collisions. SSH/SCP stages and owned
local process trees have deadlines and sanitized failure codes. Remote completion
on interruption remains UNKNOWN, not an assertion that remote work stopped.

Installation success now includes fresh image/source/HTTPS health, persistent-volume
identity and read-only schema-catalog fingerprints. A second separately connected
readback must match these values and this attempt's random nonce/controller. No
product rows, message text, attachment/TLS contents, database copies, credential
values or raw exceptions are published. Missing/failed/skipped steps cannot become
PASS. The final bounded public receipt is retained for 30 days and explicitly does
not assert human approval: environment reviewers were not configured at the last
read-only audit. No external settings or production operations changed here.

Focused tests were written before the corresponding implementation: initially
missing modules/guards were RED. Positive and negative tests cover real owned
subprocess deadline/descendant cleanup, bounded output, same-SHA artifact mutation
and rerun, controller/event/dispatch mismatch, safe ZIP extraction and tampering,
credential isolation across HTTP redirects, SSH timeout and install failure,
nonce/source/readback mismatch, volume/schema/health failures, receipt privacy,
step skipping and caller/action policy changes. Workflow validators were updated
with focused negative tests to follow the shared action instead of assuming a
duplicated download-action step. Existing producer-attempt requirements remain.

Frozen candidate validation:

- Full project-owned Python suite: **904 tests PASS**, 45.037 seconds.
- Focused shared-path/master/queue policy suite: **24 tests PASS**; additional
  focused transport/readback/receipt group: **31 tests PASS**.
- Pinned Actionlint 1.7.11: PASS; full PowerShell workflow verifier: PASS,
  **30 workflows / 2 local actions**; shell syntax and `git diff --check`: PASS.
- Traceability: **PASS_INDEX_ONLY**, all 39 indexed requirements referenced.
  The approved Windows product-brief path is unavailable on this Mac; this is
  not full source-brief validation.
- Existing Linux Bash-4 release fixtures still require hosted Linux validation;
  this Mac's system Bash is version 3. No production transport was invoked.
- The primary checkout's 12 original status entries remain unchanged, raw-status
  SHA-256 d1e8e3e43d4468617e3d6c548666c5f96db83cca5aa1a81982d6fe8fcbe044ad.

Actual GitHub download, transport, stack, queue-contention and rollback acceptance
are NOT_RUN for this candidate. The older 20-minute SCP cancellations are failures,
not proof of an installed revision or root network cause. No blind production
retries, rollback, Colima/QA VM startup, signing/account changes or Keychain prompts
were performed. Separate actual maintenance/migration measurements, consecutive
releases, same-source retry and approved compatible rollback remain required.

## Follow-up: native SQL and rollout instrumentation

The unchanged committed schema query from fb305757 was executed against an owned
empty native **PostgreSQL 17.11 (Homebrew), Darwin arm64** instance, with a private
Unix socket and no TCP listener. All 52 project migrations applied, the actual
catalog hash changed, and reapplying all 52 preserved that hash. Repeated read-only
queries were stable; a read-only CREATE TABLE negative failed without changing the
hash. The exact instance was stopped before its temporary directory was removed.
Only hashes/counts/version metadata are retained in
`delivery-schema-query-2026-10-19.json`; no database or product rows were exported.
This proves the catalog query on that native version, not the shipping Linux
PostgreSQL 17.6 container, Docker install, production, rollback or media gates.

Procedure: `initdb` a new private temporary empty cluster as the fixed QA role;
start it with `-h ''` and a private Unix socket; execute the committed catalog query
with `PGOPTIONS=-c default_transaction_read_only=on`; apply each sorted project
migration with `psql -X -qAt -v ON_ERROR_STOP=1 -f`; compare repeated hashes, reapply
all migrations and verify a rejected read-only DDL statement; stop only that exact
cluster with `pg_ctl -D <owned directory> -m fast -w stop`, then remove the owned
temporary directory. No existing instance, application credentials or data enter
this procedure.

New signed rollout runtimes now emit ten fixed phase/time markers into the current
installer's private temporary file. Complete ordered events produce explicit
one-second-resolution rollout/maintenance/migration/health intervals; an empty
legacy runtime reports NOT_AVAILABLE_LEGACY. Partial or inconsistent timing cannot
be published as PASS. Actual marker propagation and the existing deploy/volume/
rollback guards passed the three shipping shell fixtures with fake Docker; the
Python owned-shell fixture confirms private-file cleanup. These are fixture checks,
not a real rollout/rollback. New whole-candidate checks and hosted results remain
separate from the earlier 904-test checkpoint.

Follow-up whole candidate: **912 Python tests PASS**, 45.065 seconds; focused
readback/timing/transport/receipt group **30 PASS**. All three shipping shell
fixtures completed successfully: deploy phase/order/error handling, registry
headroom ordering and controlled fake-Docker rollback. These individual fixtures
run on this Mac's Bash 3; the full release-fixture wrapper still requires Bash 4+
and hosted validation. The earlier 904-test checkpoint remains attached to its
published source fb305757. Hosted CI39283110808 was still queued at the last
read-only observation, so no GitHub PASS is asserted.

## Actual retained ZIP verification and exact health status

The real retained master producer39268498370/sourcefe482 attempt1 bundle
artifact12195206890 was downloaded through the authenticated connector's file
reference. Complete actual API collections (11 jobs,16 artifacts) and producer
reads before/after the local file transfer remained unchanged; the common trusted
preflight accepted that exact authority. The actual ZIP measured73502109 bytes,
SHA-256 a2c356fa784c7a480e3402062ffbe15913bae1abb0525b203eec534f010d88fe;
the inner exact transport pair and checksum passed. Five controlled negatives on
this real archive/metadata rejected wrong source, digest, size, producer run and
requested source, with no partially published output. Relevant verification
modules were byte-identical to committed8b11e744, and their hashes are recorded.

The first local connector-file transfer timed out at120s with60738841 bytes;
Range-resuming the same file completed, followed by exact full ZIP verification.
This is not a production SCP retry, downloader throughput/SLO claim or successful
installation. No code/images from the bundle were executed. Host signature,
new Python API downloader transport, SSH, installation and full-stack acceptance
remain NOT_RUN. The bounded sanitized record is
`delivery-artifact-actual-2026-10-19.json`; no signed URL/token or archive is staged.

A focused health negative then reproduced five false-positive cases because curl
`--fail` accepts redirects:301/302/204, empty and malformed status. Fresh health
now captures only the bounded HTTP status and requires exactly200. Response body
and environment remain discarded. The committed schema-query proof predates this
unrelated health change; its recorded source/file hash remains exact, and the SQL
query itself is unchanged. New whole-candidate validation is recorded separately.

Latest candidate: **913 Python tests PASS**, 48.074 seconds after the exact-HTTP-200
health fix; focused health/readback acknowledgement group **15 PASS**. Traceability
again PASS_INDEX_ONLY39. This does not change the NOT_RUN boundaries above.

## Shipping network path acceptance runner

The separate `Trusted delivery acceptance` workflow now runs the actual shipping
producer preparation, API/blob download and fresh producer recheck, with read-only
Actions/contents authority and no production environment or SSH configuration.
It selects the same actual retained master producer39268498370/sourcefe482 and
uploads only a sanitized, source/module-bound transport receipt for30 days.
Signature and installation are explicitly NOT_RUN; neither a connector download
nor a successful transport receipt can satisfy the full installation gate.

Focused failure-handling/workflow tests were written first (missing implementation
and workflow RED), then all four passed. Whole candidate: **917 Python tests PASS**,
46.149 seconds; actionlint1.7.11 PASS; full PowerShell workflow policy PASS for
**31 workflows /2 local actions**; traceability PASS_INDEX_ONLY39. At this checkpoint
the new workflow has not run: its real network result remains NOT_RUN. GitHub's
19October Actions/status-update incident is external evidence, not a code PASS.
The QA x86_64 VM was started without activating its Docker context; the existing
default context and the12 original primary-checkout status entries are unchanged.
