# Issue 689: bounded roster normalization

- PASS: twenty Go package runs, three Linux race-detector runs, Go vet and specification traceability. Empty lists remain explicit, sort order is deterministic, input is not mutated, malformed/duplicate data and oversize results fail rather than becoming empty rosters.
- NOT RUN: coordinator, per-recipient ACL/session recheck, server frame-size bound, LiveKit/DB integration and load. The caller supplies a byte limit; no channel-count product limit is introduced.
