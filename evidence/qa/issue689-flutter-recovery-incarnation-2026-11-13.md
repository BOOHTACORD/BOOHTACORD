# Issue #689: Flutter recovery incarnation, partial

- A regression reproduced an old connection-ready event being applied after a
  second socket had already recovered, when the first recovery completed late.
- The delivery owner now rechecks its epoch after recovery before dispatching
  ready. Seventeen focused delivery, security and handoff tests and Flutter
  analysis passed. Existing durable cursor ordering tests were included.
- Recovery operations already started may still mutate their own stores and
  require independent ownership checks. Native Android/iOS, full current-source
  real-stack and visual acceptance remain NOT_RUN for this change.
