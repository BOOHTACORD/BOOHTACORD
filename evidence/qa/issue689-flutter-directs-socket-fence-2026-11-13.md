# Issue #689: Flutter direct navigation socket fence, partial

- App-composition regressions reproduced an old direct list and late candidate
  list updating state after socket end.
- Socket-scoped direct loads are invalidated on socket end; candidate responses
  also check request ownership. Independent initial loads remain valid and old
  failures are ignored. The HTTP work is not aborted.
- Four focused regressions within 61 related tests and Flutter analysis passed.
  Native Android/iOS, full current-source real-stack and visual acceptance
  remain NOT_RUN; other recovery stores require separate ownership checks.
