# Issue 689: Flutter maintenance guest/auth handoff

**Route:** maintenance controller and authenticated socket composition.

- [ ] Test guest-to-auth-to-guest handoff, socket-attempt ownership and unknown state without overlap or stale callbacks.
- [ ] Replace the legacy maintenance SSE controller with public/authenticated WebSocket ownership; bind lifecycle to login, logout, expiration and server changes.
- [ ] Run focused Flutter tests, visual scenarios and real Android AVD checks. iOS/desktop, full stack/load and release gates remain separate.
