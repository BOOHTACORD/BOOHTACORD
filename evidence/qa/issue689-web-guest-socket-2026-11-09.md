# Issue 689: Web guest socket owner

- PASS: ten focused Web tests across guest transport, state and payload; TypeScript/Vite build; local-feature registry policy and spec traceability.
- NOT RUN: real browser connection, application guest/auth handoff and screenshot acceptance. The owner is not wired into the application, and legacy SSE remains active.
