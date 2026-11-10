# Issue 689 Web maintenance handoff

**Goal:** Show one shared maintenance state while switching between guest and authenticated application sockets.

**Route:** Web maintenance owner and its exact App/Workspace injection edges.

- [x] Test startup, login/logout handoff, rapid transitions and stale-owner isolation.
- [x] Confirm RED; connect guest socket and authenticated state to the same feature owner, removing Web maintenance SSE.
- [ ] Complete local feature gate and visual cases; browser and unit results are recorded, while release compatibility and remaining platforms are unfinished.
