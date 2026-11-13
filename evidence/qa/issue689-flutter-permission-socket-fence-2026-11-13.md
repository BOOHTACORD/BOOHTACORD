# Issue #689: Flutter permission socket fence, partial

- An app-composition regression reproduced a realtime permission response
  updating the snapshot after its owning socket ended.
- Socket end now invalidates the current realtime permission request while
  retaining its last snapshot. Independent initial loads are not cancelled.
  The underlying HTTP request may still run; its late result is ignored.
- Fourteen focused permission, priority and app-composition tests passed.
  Android/iOS runtime, current-source real-stack and visual acceptance remain
  NOT_RUN; other in-flight workspace callbacks require separate review.
