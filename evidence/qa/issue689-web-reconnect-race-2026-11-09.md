# Issue 689: Web reconnect race

- PASS: RED tests reproduced an extra socket and an erroneous session expiry after manual reconnect. The fixed version passed 22 focused realtime tests and the full Web run (529 files / 1819 tests), plus TypeScript/Vite build.
- NOT RUN: real network fault scenario and final local feature gate. The full run included uncommitted handoff work at the time; this is not release acceptance.
