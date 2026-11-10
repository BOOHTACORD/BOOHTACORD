# Issue 689: retire public SSE routes

**Route:** server status and voice participant route composition.

- [x] Add failing tests that require both legacy routes to be absent.
- [x] Unregister routes, keep REST snapshots and signed webhook, and update OpenAPI and mobile contract.
- [x] Run route tests, contract parity and spec traceability.
- [ ] Remove now-unreachable stream implementations after migrating relevant security and fault coverage to the socket path.
- [ ] Complete coordinated client cutover, compatibility/rollback documentation and release acceptance.
