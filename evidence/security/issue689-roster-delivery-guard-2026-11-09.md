# Issue 689: roster delivery guard

- PASS: focused tests and isolated real PostgreSQL fixture without skips cover valid/empty snapshots, changed topology/name, exact lease revocation, session revocation during visibility check, session mismatch and safe unavailable errors. Linux race detector and Go vet passed; spec traceability passed.
- The guard authenticates both before and after the current visibility/lease query. It returns only fixed error classes and does not expose tokens, internal lease proof or database details.
- NOT RUN: integration into the serial socket writer, revocation between the final check and actual network write, LiveKit behavior and load. This isolated guard alone does not prove the required no-leak delivery guarantee.
