# Issue 689: maintenance initial latency investigation

- Baseline: two local 100-account/20-room smoke comparisons show initial
  maintenance p95 around 52–55 ms for the candidate and 9–11 ms for baseline.
  They use a dirty driver/source and are diagnostic, not release evidence.
- Leaf: maintenance shared observer. Preserve subscribe-before-read, unknown
  state, bounded concurrent reads and server-local change detection.
- Verify paced subscribers are coalesced, then test a shorter fixed minimum
  read spacing under the same guarded fixture. Record p95 and observer-read
  count; investigate increased database pressure and revert if bounds regress.
- Stop condition: test and comparative evidence distinguish initial latency
  from actual maintenance change propagation. Full immutable matrix, outages,
  storm, capacity and production acceptance remain separate open gates.
