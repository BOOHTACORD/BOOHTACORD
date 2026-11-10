# Issue 689 Web Maintenance Event Parsing Plan

> **For agentic workers:** Execute this leaf inline. Parsing alone does not create a connection or claim UI acceptance.

**Goal:** Validate new maintenance event payloads in the existing Web realtime parser.

**Architecture:** Keep the shared event envelope and place strict maintenance payload validation in a small dedicated module. Both kinds remain ephemeral and cannot become journal cursors.

**Tech Stack:** Vue/TypeScript, Vitest, existing realtime JSON Schema.

---

### Task: Parse maintenance snapshot and change

**Files:**
- Create: `clients/web/src/realtime/maintenance_payload.spec.ts`
- Create: `clients/web/src/realtime/maintenance_payload.ts`
- Modify: `clients/web/src/realtime/realtime_client.ts`
- Modify: `tools/qa/local_features/features.json`
- Modify: `backlog/tasks.yaml`

- [x] Add positive and negative parser cases matching the contract, including non-safe revisions and private extra fields.
- [x] Run `npm test -- src/realtime/maintenance_payload.spec.ts` from `clients/web` and confirm RED.
- [x] Add the two kinds and exact typed validation; preserve all existing event parsing.
- [x] Run the focused parser and realtime tests, full Web unit suite, Web build, contract and traceability checks.
- [ ] Complete the registered real-stack browser and visual gate after delivery and guest/auth ownership exist; parser tests do not prove those behaviors.
