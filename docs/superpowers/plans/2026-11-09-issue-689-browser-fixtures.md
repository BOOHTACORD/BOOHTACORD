# Issue 689: browser test transport and mobile acceptance

**Route:** browser fixture transport and owned voice/search acceptance.

- [x] Replace the obsolete stream mock with public/authenticated WebSocket events.
- [x] Test guest privacy, stale closure and explicit unknown maintenance state.
- [x] Repair the mobile voice scenario to open navigation before workspace search.
- [x] Include the new tests and existing WebSocket tests in the lifecycle gate.
- [ ] Repeat the full browser gate and real-stack mobile scenario on stable source.
