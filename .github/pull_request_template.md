Describe the user-visible problem, resulting behavior and focused verification.

For each changed shared scenario, update its `parity_review` in
`tools/qa/local_features/features.json`:

- [ ] Web implementation + regression, or a linked gap / justified platform exception.
- [ ] iOS implementation + regression, or a linked gap / justified platform exception.
- [ ] Android implementation + regression, or a linked gap / justified platform exception.
- [ ] Separate runtime evidence per platform, source SHA and build; shared Dart/widget tests do not imply two native PASS results.

Record unavailable physical capture/background/audio checks as NOT_RUN with the
existing acceptance issue. Do not copy an old runtime PASS to a new build.
