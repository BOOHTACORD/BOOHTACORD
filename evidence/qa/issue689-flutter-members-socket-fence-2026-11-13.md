# Issue #689: Flutter member list socket fence, partial

- App-composition regressions reproduced old member data overwriting a newer
  socket result or appearing after socket end.
- Member loads retain profile-revision preservation, reject superseded or old
  socket results and failures, and clear the loading indicator on invalidation.
  Independent initial loads remain valid; underlying HTTP work is not aborted.
- Four focused regressions, 60 related tests and Flutter analysis passed. Native
  Android/iOS, full current-source real-stack and visual acceptance remain
  NOT_RUN; other recovery stores require independent ownership checks.
