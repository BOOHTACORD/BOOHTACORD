# Issue #689: Flutter text history socket fence, partial

- An app-composition regression reproduced an old text-history response
  updating the selected channel after socket closure and starting topology work.
- Realtime text history checks socket admission before applying a response;
  later topology and notification steps are also fenced. Independent history
  loads retain their existing behavior and loading cleanup remains bounded.
- Two focused cases within 61 related tests and Flutter analysis passed. Native
  Android/iOS, full current-source real-stack and visual acceptance are NOT_RUN.
  Other already-running operations remain separate review items.
