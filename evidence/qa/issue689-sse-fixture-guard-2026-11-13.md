# Issue #689: SSE guard fixture boundaries, partial

- The migration guard previously ignored every file with a test-like name or
  directory, so an unreviewed file with active SSE code could evade the scan.
- Only 13 explicit baseline/negative fixtures now receive exceptions, each
  bound to normalized UTF-8 content by SHA-256. Changed or missing fixtures
  fail closed, including if the changed file no longer contains an SSE marker.
  The guard's own source remains an explicit exception for its pattern list.
- Twelve boundary/inventory tests, seven realtime schema tests, the native
  contracts check and the repository scan passed; the scan found zero active
  findings. This is source evidence, not a running-client or production proof.
- Preventing test/baseline imports into runtime remains a separate open check.
