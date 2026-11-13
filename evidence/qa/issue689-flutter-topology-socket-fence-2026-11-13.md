# Issue #689: Flutter topology socket fence, partial

- App-composition regressions reproduced an old realtime topology result
  being applied after socket end, including after a newer response.
- Realtime topology requests are invalidated at socket end and superseded by
  newer loads. Independent initial loads remain valid; old failures do not
  reach a new owner. The underlying HTTP work is not aborted.
- Four focused regressions, 61 related app/composition tests and Flutter
  analysis passed. Already-started channel selection and other recovery stores
  require separate fencing. Android/iOS, full current-source real-stack and
  visual acceptance remain NOT_RUN for this change.
