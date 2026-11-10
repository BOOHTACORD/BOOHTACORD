# Issue 689: Flutter manual realtime reconnect

- PASS: ten focused tests cover closing an existing fake socket, retaining the applied durable cursor, invalidating an old session check and closing a late socket from a replaced attempt. Targeted analyzer and spec traceability passed.
- NOT RUN: manual reconnect through the application on Android, OS/network failure during close, other native platforms and final load/release acceptance.
