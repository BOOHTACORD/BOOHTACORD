# Issue 689: Web roster event parsing

- PASS: 15 focused parser/reconnect tests, TypeScript/Vite build, local-feature registry policy and specification traceability. Tests cover strict payloads, duplicate identifiers, invalid dates, Unicode names, safe unavailable errors and unchanged durable replay cursor.
- NOT RUN: Web roster store/UI application, server capability negotiation, real browser delivery, fault cases or load. The new events are not enabled on the server yet.
