# Issue 689: Web maintenance handoff

- PASS: 529 Web test files / 1819 tests, TypeScript/Vite build, registry policy and specification traceability. Maintenance state remains explicitly unknown while disconnected and retains the last active warning.
- PASS (preliminary): Chromium on the owned Docker/PostgreSQL/LiveKit/Caddy fixture received guest and authenticated snapshots, observed CLI enable/disable in both modes, completed login/logout and returned to one guest socket; network instrumentation saw no Web maintenance SSE. Voice roster SSE is still active. Earlier runs failed on test harness selectors or CLI invocation and were corrected.
- Visual observation: desktop guest and workspace screenshots were inspected at 1280×800, with controls visible and no obvious text clipping. They do not cover the maintenance warning, unavailable state, mobile viewport or media.
- LIMITATION: the real-stack image was built from `907adf8ef` plus uncommitted Web handoff/reconnect changes, not an immutable candidate. The registered local feature `--real-stack` gate, mobile and physical devices, full SSE removal, release compatibility and load remain NOT RUN.
