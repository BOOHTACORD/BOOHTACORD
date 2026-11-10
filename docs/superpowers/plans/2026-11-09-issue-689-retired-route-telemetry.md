# Issue 689: retired route telemetry

**Route:** HTTP request classification and central projection allowlist.

- [x] Test that removed routes are no longer classified as service operations.
- [x] Remove their operational skip rules and central operation names; retain other fixed routes.
- [x] Split the overlong operation map by read/write entries and run focused native tests.
- [ ] Replace SSE-only metrics and dashboards after equivalent WebSocket coverage is present.
