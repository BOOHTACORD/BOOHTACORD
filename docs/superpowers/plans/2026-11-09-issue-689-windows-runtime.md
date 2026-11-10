# Issue 689: local Windows runtime smoke

**Route:** owned real-stack native QA scenario on Windows x64.

- [x] Reject unsupported desktop targets and constrain the runner to the issue689 scenario.
- [x] Use in-memory preferences and secure storage on Windows so the test cannot modify the user's stored server or session.
- [x] Run the native desktop scenario against the disposable local stack and report mocked storage explicitly.
- [ ] Complete visual, installed release, media and full Windows acceptance separately; this smoke cannot close those gates.
