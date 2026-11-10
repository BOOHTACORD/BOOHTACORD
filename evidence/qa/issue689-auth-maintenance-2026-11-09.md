# Issue 689: authenticated maintenance stream

- PASS: full authenticated realtime package tests with isolated PostgreSQL fixture, no skips; Linux race detector on maintenance and existing handler tests. Legacy connection receives no maintenance events; capability-enabled connection receives initial state and change, and closes on unknown state.
- PASS: spec traceability. Existing session-validation helpers moved without semantic change to keep files within the size ratchet.
- NOT RUN: shared runtime wiring, browser/Flutter negotiation, CLI/stand and load. This packet alone does not enable authenticated maintenance in the app.
