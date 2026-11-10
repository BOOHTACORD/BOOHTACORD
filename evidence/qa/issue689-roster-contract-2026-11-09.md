# Issue 689: voice roster contract

- PASS: JSON Schema tests for empty and populated rosters, strict participant fields, safe unavailable code and rejection of malformed/private fields; native contract and specification checks passed. Display name length matches the existing database constraint.
- NOT RUN: server emission, client parsing, actual payload/frame bounds, ACL/revocation, SFU integration and load. The schema does not impose a new product limit on channel count.
