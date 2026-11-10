# Issue 689: public connection admission

- PASS: unit tests, 20 repetitions, including 20 connections from one NAT, IPv4-mapped address normalization, global saturation and idempotent concurrent release.
- PASS: Linux Go race detector, three repetitions; specification traceability verifier.
- NOT RUN: actual WebSocket handshakes, proxy deployment and load. The quota is not yet connected to a route; these tests do not establish production capacity.
