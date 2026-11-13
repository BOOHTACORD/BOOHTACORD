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
- A separate import check rejects literal Web and Flutter imports of named
  fixtures or test modules, and production Go imports of the legacy load
  package. Thirteen focused tests and the repository scan passed after this
  addition; the contracts check also passed.
- This is a static source check for supported literal import forms, not proof
  against computed imports, all aliases, native binaries, or production use.
  The separately requested full acceptance and deployment evidence remain open.
