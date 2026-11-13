# Issue 689: session pool isolation

Outcome: **partial PASS; release gate incomplete**.

## Setup

The owned fixture uses PostgreSQL 17.6 and a two-CPU container limit on WSL2.
All clients and synthetic messages are local; no production database or user
data was used. The command was:

`python3 -m tools.load.controller.run --accounts 100 --seconds 120 --profile reconnect`

The profile exercises warmup, 50-account ramp, 100-account steady state,
spike, recovery and saturation stop. It does not prove real network, NAT,
voice media, device UI or populated roster behavior.

## Results

- Local source `ba7d09dd80ff3aa41b8be38aa21850ec42bbfe01` passed all
  phases with 345,018 fanout deliveries, zero recorded delivery errors and
  delivery p95 361.35 ms. The aggregate pool maximum was 20 and owned-resource
  cleanup passed. Report: `Q:\Codex\issue689-reconnect100-ba7d-run1.json`.
- Local source `1b2bd6ad493040e30f532cb9a626c2f4b4888701` passed all
  phases with 290,018 fanout deliveries, zero recorded delivery errors and
  delivery p95 383.46 ms. The aggregate pool maximum was 20 and owned-resource
  cleanup passed. Report: `Q:\Codex\issue689-reconnect100-1b2b-run2.json`.
  The sole difference from the first source was regenerated signal catalog
  metadata; the runtime code was identical.
- Under this load, topology p95 was approximately 1.54 s and 1.58 s
  respectively. The runs are not a baseline comparison and do not establish
  absence of latency regression.

Disposable PostgreSQL integration tests also verified that a session lookup
can succeed with the main pool saturated, a revoked session is rejected, and
the metrics report both pools. Security, real-client and production acceptance
are still required. See the earlier load evidence for failures and the
diagnostic-only prototype.
