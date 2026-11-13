# Issue #689: Flutter social handoff fence, partial

- A focused regression reproduced an old ready event reaching application
  dispatch after an awaited social observer and socket closure.
- The app now rechecks the socket admission generation after that await and
  before notifying listeners after dispatch. Nine focused tests and Flutter
  analysis passed. An observer or dispatch already running still owns its
  own late effects and must fence them independently.
- Current-source Android and iOS runtime, full real-stack and visual review
  remain NOT_RUN for this change.
