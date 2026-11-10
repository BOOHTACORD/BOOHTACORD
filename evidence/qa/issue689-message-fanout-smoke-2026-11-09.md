# Issue 689: preliminary message fanout comparison

- Local owned Docker fixture, synthetic accounts, Go 1.26.4, PostgreSQL 17.6,
  LiveKit 1.13.7; 100 authenticated users, 20 empty voice rooms, ten sequential
  messages and one maintenance change per run. Both versions used the same
  dirty driver. Baseline opened the original two SSE streams alongside its app
  WS; candidate used its single app WS for all application events.
- Each report recorded 1000 message-hint deliveries. Aggregate p95 to synthetic
  socket processing in milliseconds:
  - baseline: 22.7 (`baseline-100-20-change-20261109T064927Z-01803396`),
    23.4 (`baseline-100-20-change-20261109T065117Z-a396c564`), and
    21.3 (`baseline-100-20-change-20261109T065429Z-6ac69680`);
  - candidate: 47.0 (`candidate-100-20-change-20261109T064823Z-7e23d51d`),
    57.7 (`candidate-100-20-change-20261109T065222Z-ca3f29ef`), and
    45.0 (`candidate-100-20-change-20261109T065324Z-7461c4a9`).
  Reports live under `.out/roster-matrix/` with the indicated directory names.
- The latter four runs alternated order and verified the dirty candidate source
  fingerprint before and after each; all six reported owned cleanup success.
  A closed diagnostic guard client caused a BrokenPipe traceback in two baseline
  runs; guard samples otherwise passed, but this is recorded as a limitation.
  A focused test reproduced the handler attempting a second response and the
  handler was corrected after these samples were taken.
- The original driver stopped looking for duplicates as soon as all recipients
  had seen a message. Its zero duplicate field is therefore limited to that
  window and does not prove absence of later duplicates. A new 100 ms bounded
  observation window and per-message summaries were added after these runs;
  numbers across the two driver versions are not directly interchangeable.
- These tests do not measure real UI application, voice media, long-term
  throughput or full capacity. The candidate's higher initial-snapshot latency,
  DB acquisition count and message p95 remain under investigation. Repeated
  synthetic samples do not establish statistical significance or production
  readiness; immutable comparisons, failure scenarios and platform gates remain
  NOT_RUN.

## Follow-up with bounded duplicate window

After adding a 100 ms post-delivery observation window and per-message summaries,
a fingerprint-stable dirty driver ran a new sequence, again with 100 accounts
and ten messages per run. All four runs completed, removed their own resources,
and observed no duplicate within the bounded window:

| Version | Empty rooms | Aggregate p95 ms | First message p95 ms | Report directory under `.out/roster-matrix/` |
| --- | ---: | ---: | ---: | --- |
| baseline | 0 | 23.1 | 23.3 | `baseline-100-0-change-20261109T070652Z-7f5eb7e0` |
| candidate | 0 | 54.0 | 57.0 | `candidate-100-0-change-20261109T070755Z-b11b4c6b` |
| candidate | 20 | 36.5 | 38.6 | `candidate-100-20-change-20261109T070907Z-c814856f` |
| baseline | 20 | 22.6 | 25.4 | `baseline-100-20-change-20261109T071008Z-bd29fc82` |

The first message was sent as soon as the initial snapshots were collected;
subsequent candidate message p95 values in these two runs were 7–16 ms. This
suggests a post-connection effect, but does not identify its cause. Counts and
latencies measure a synthetic client parsing socket events, not UI rendering.
The candidate source was dirty during these runs; they are not immutable
final-build acceptance evidence.

## One-second post-connect pause

With identical 1000 ms post-snapshot pauses, the same dirty synthetic driver
completed four further cells, all with 1000 deliveries and no duplicates within
its 100 ms observation window. First-message / overall p95, respectively:

- baseline 0 rooms: 26.6 / 26.5 ms, `baseline-100-0-change-20261109T071427Z-67a6fccd`;
- candidate 0 rooms: 39.5 / 38.7 ms, `candidate-100-0-change-20261109T071536Z-bbc6241f`;
- candidate 20 rooms: 48.7 / 46.0 ms, `candidate-100-20-change-20261109T071643Z-311adf7c`;
- baseline 20 rooms: 23.6 / 21.6 ms, `baseline-100-20-change-20261109T071751Z-a14bf918`.

All four had matching candidate source fingerprints before and after and clean
owned-resource removal. Subsequent sends showed lower latency, but a one-second
pause did not eliminate the first-send difference. These measurements do not
identify its cause, establish real-user latency, or close release gates.

## Presence-event diagnostic

A separate fingerprint-stable comparison counted `presence.changed` events
without retaining event identities. With 100 accounts, 20 empty rooms and no
warmup, both implementations observed 5050 presence events before the first
message and zero more through the first delivery plus 100 ms. First-message p95
was 21.6 ms for `baseline-100-20-change-20261109T072119Z-5b7ebc58` and
49.6 ms for `candidate-100-20-change-20261109T072226Z-20234b85`. Both runs
recorded all 1000 synthetic deliveries, no duplicates in the bounded window,
and successful cleanup. This rules out only a remaining queue of these
presence events in this pair; it does not identify the latency cause or prove
that other event classes, resource work, runtime differences, or network
conditions had no effect.

## HTTP receipt and first fanout timing

A later dirty-worktree comparison added independent measurement of the HTTP
response receipt. Four alternating 100-account, 20-empty-room cells used the
same bounded driver, ten messages and 100 ms duplicate observation window;
all recorded 1000 deliveries, no duplicates within the window, stable source
identity during each run, and owned-resource removal. First-message timings:

| Version | HTTP response ms | Socket p50 / p95 / p99 ms | Report |
| --- | ---: | ---: | --- |
| baseline | 11.35 | 21.92 / 23.94 / 24.53 | `baseline-100-20-change-20261109T102443Z-13bb5711` |
| candidate | 9.41 | 43.30 / 45.94 / 46.75 | `candidate-100-20-change-20261109T102550Z-94bbf500` |
| candidate | 8.96 | 47.49 / 49.04 / 50.32 | `candidate-100-20-change-20261109T102702Z-f0a34489` |
| baseline | 9.40 | 18.23 / 20.63 / 22.39 | `baseline-100-20-change-20261109T102804Z-56dc9a43` |

HTTP and socket timings share the same client start time, but events may arrive
before the HTTP response; subtracting them does not isolate a server stage.
These numbers narrow the investigation but do not identify a cause. The
measurements do not cover UI application or voice media and do not close the
immutable-release or load gates. A subsequent driver change adds bounded,
identity-free counters for roster and maintenance events around first delivery;
its results must be reported as a separate measurement series.

## Additional snapshot-event diagnostic

A later instrumented pair counted only fixed event categories, without retaining
account, channel or message identities. Each run used 100 accounts, 20 empty
rooms, ten messages and a 100 ms observation window. Both recorded 100 roster
and 100 maintenance initial events before the first send, then zero further
roster or maintenance events and zero presence events through first delivery
and the bounded window. First response / delivery p95: baseline 10.18 / 21.83 ms
(`baseline-100-20-change-20261109T103108Z-163061d9`), candidate 10.25 / 48.98 ms
(`candidate-100-20-change-20261109T103216Z-f0656580`). Both report SMOKE_PASS,
1000 deliveries and owned cleanup. These counts rule out only those observed
additional event classes in this pair; they do not determine the delay's cause.

## Server event creation timestamp diagnostic

A separate dirty-worktree pair measured the server's `occurred_at` timestamp
and client receipt using the shared WSL/Docker host wall clock. In the baseline
run (`baseline-100-20-change-20261109T103702Z-bed8e161`), event creation was
7.80 ms after send start and socket processing age p50/p95/p99 was
15.23/15.43/16.05 ms. In the candidate run
(`candidate-100-20-change-20261109T103807Z-e43454d9`), creation was 6.33 ms
after start and age was 42.94/46.05/46.27 ms. Both returned SMOKE_PASS,
recorded all 1000 deliveries, maintained source identity, and removed owned
fixtures. These are wall-clock measurements on one host; they do not separate
journal publication, server socket writes, proxy/network and client processing.

## Server WebSocket-write histogram diagnostic

The same-host dirty-worktree pair sampled the existing server delivery
histogram immediately before and after the first message. The probe itself adds
fixture work and may change timing; compare only within this instrumented pair.
Each delta contained exactly 100 successful writes, with no other observed
presence/roster/maintenance events in the bounded window. Baseline
`baseline-100-20-change-20261109T104218Z-a356f5f1`: 100/100 writes within
25 ms, mean 12.20 ms from event creation to completed server write, client
age p95 16.31 ms. Candidate
`candidate-100-20-change-20261109T104323Z-bd585f77`: 0/100 within 25 ms,
100/100 within 50 ms, mean 39.99 ms, client age p95 44.49 ms. Both reported
SMOKE_PASS, 1000 deliveries and owned-resource removal. This locates the
observed difference by server write completion; it does not prove which part
of publication, authorization, scheduling or socket writing caused it.

## Session revalidation and database acquisition diagnostic

A further instrumented baseline/candidate pair took fixed, identity-free metric
snapshots before and after first-message delivery, including the 100 ms settle
window. The guard probes add work, so these are diagnostic comparisons, not
capacity measurements. Both windows included exactly 100 server writes, all
1000 workload deliveries, matching source identities and owned cleanup.

- Baseline `baseline-100-20-change-20261109T104617Z-8f0d03ff`: first-event
  client-age p95 17.52 ms; 117 DB acquisitions, 0.920 s cumulative acquire
  duration, zero completed session revalidations in the window; mean server
  event-write latency 13.13 ms.
- Candidate `candidate-100-20-change-20261109T104721Z-b844f45f`: first-event
  client-age p95 40.29 ms; 177 acquisitions, 0.908 s cumulative acquire
  duration, 55 completed session revalidations in the window; mean server
  event-write latency 31.80 ms. Revalidations totaled 0.031 s of observed
  duration. Both DB pools had max 20; gauges sampled at the endpoints do not
  establish their peaks during the window.

These aggregate counters show more revalidation activity on the candidate,
but similar cumulative DB acquire duration in this pair. They do not establish
causation or rule out CPU, query execution, contention or scheduling effects.

## Server delivery stages and CPU guard correction

Three candidate-only runs added no-identity, fixed-stage server histograms.
Each first-message window captured exactly 100 writes, 1000 total workload
receipts, stable source identity and clean owned-resource removal. Reports and
first-message total p95 / mean before-handler / mean inside-handler in ms:

- `candidate-100-20-change-20261109T105322Z-cd043123`: 28.73 / 7.85 / 11.71;
- `candidate-100-20-change-20261109T105516Z-6e288e5c`: 57.82 / 21.69 / 21.33;
- `candidate-100-20-change-20261109T105621Z-e1bcacc9`: 57.83 / 25.88 / 19.53.

Before-handler includes journal publication and any queuing; handler includes
session/authorization/correlation and socket write, so neither stage alone
identifies the cause. Histograms and the guard sampling add overhead. The
instrumented results vary and are not an immutable-release comparison.

Review of the load safety guard found that `CPUPercent` was normalized by the
20-CPU host even though the owned API container has a 2-CPU quota. Historical
CPU samples therefore understate fraction of that quota by a factor of ten on
this host; the prior CPU safety threshold cannot be claimed quota-relative.
The guard was corrected to read the owned container's bounded Docker CPU quota,
normalize by the lower of quota and host CPUs, and fail closed when quota is
missing or unbounded. The new calculation has focused tests; future load runs
must be repeated with the corrected guard.

## Recheck with quota-relative CPU guard

The corrected guard was exercised on the real owned fixture: the one-account
smoke (`candidate-1-0-20261109T105901Z-7a6a5c07`) passed and cleaned up.
A subsequent 100-account, 20-empty-room diagnostic pair used the same corrected
driver and bounded duplicate window:

- Candidate `candidate-100-20-change-20261109T110029Z-dfd583b9`: first-event
  p95 50.07 ms, age p95 43.62 ms, maximum sampled interval CPU 45.49% of the
  two-CPU container quota.
- Baseline `baseline-100-20-change-20261109T110218Z-5e38ec0b`: first-event
  p95 21.16 ms, age p95 14.06 ms, maximum sampled interval CPU 36.71% of the
  same quota.

Both runs were SMOKE_PASS with 1000 deliveries, stable source identity and
owned-resource removal. CPU values are interval averages, not instantaneous
peaks; snapshots do not prove absence of short throttling or host contention.
The candidate includes the new stage instrumentation and the baseline does not.
The regression remains unexplained and this dirty-worktree pair does not close
the comparative load gate.
