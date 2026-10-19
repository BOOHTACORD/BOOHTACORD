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
retries, rollback, local daemon startup, signing/account changes or Keychain prompts
were performed. Separate actual maintenance/migration measurements, consecutive
releases, same-source retry and approved compatible rollback remain required.
