# Issue #689: Flutter direct history socket fence, partial

- An app-composition regression reproduced an old direct-message history
  response updating the selected conversation after the socket closed.
- Realtime direct history captures socket admission and checks it before
  applying a response or starting subsequent navigation and notification work.
  The current socket path continues to apply history normally.
- Two focused cases within 63 related tests and Flutter analysis passed. Native
  Android/iOS, full current-source real-stack and visual acceptance are NOT_RUN.
  Text history and other in-flight operations remain separate review items.
