# Issue 689: static realtime migration guard

**Route:** `tools/verify/realtime_migration`.

- [x] Test detection in backend, Web, Flutter and QA sources, with an exact exception for the historical comparison driver and negative contract assertions.
- [x] Implement a fail-closed scanner that reports paths and line numbers without source contents.
- [ ] Remove the remaining reported legacy adapters and migrate active QA harnesses.
- [ ] Wire the clean scanner into CI and run the complete native checks.
