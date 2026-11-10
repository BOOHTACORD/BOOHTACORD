# Issue 689: prepared roster socket adapter

- PASS: negotiated capability receives a snapshot; a client without it does not subscribe. Stale coordinator states request refresh instead of being emitted. Unavailable and invalid-session signals have fixed behavior.
- PASS: size test checks the complete encoded WebSocket frame and returns unavailable rather than truncating; internal lease proof does not appear in JSON. Full connect-session tests passed against disposable isolated schemas on the local PostgreSQL stand with no skips, along with Go vet, five focused Linux race-detector runs and spec traceability.
- NOT RUN: the adapter is not wired to a live coordinator or enabled in clients. Session/ACL changes between the asynchronous guard and the actual socket write, terminal-event priority, real LiveKit, end-to-end and load acceptance remain unproven. This packet is not evidence of a safe production cutover.
