# Recent bug fixes implementation plan

**Goal:** Correct GitHub #584/#585/#586/#587/#589 with focused regressions and explicit runtime limits.
**Architecture:** Keep existing Flutter/Vue capabilities and protected API reads. Process one trigger family per packet; preserve server ACL, media transport and session boundaries.
**Tech stack:** Flutter/Dart, Vue/TypeScript/Pinia, Kotlin/WebRTC.

Operating brief: workflow_class=split_first; task_size=large; structure_mode=structure_no_rg; search_stage=exact_edges.
Base: origin/master 8a2cda38bee5a4d8f7988eb4eefbfa176a62c43a. No existing changes copied.
Ratchet: new implementation/tests <=120 lines/file; <=16 production files per leaf. Existing large presentation files receive only narrow bindings, no conversion.

- [x] #585 / FV2-016: `admin/members/layout/presentation.dart` owns the editor list identity. Regression `test/admin_accessibility/search_focus_test.dart` sends four editing updates without refocusing and asserts the same focus node, connected/visible IME, retained query and reset. Keep the filter-keyed results-only list; use a stable `PageStorageKey('admin-member-form')` for the list containing the editor. Native check: `flutter test test/admin_accessibility/search_focus_test.dart test/admin_member_filter_test.dart`.
- [x] #586 / FV2-019: `workspace_search_panel/build/scope_field/handler.dart` owns scope interaction. Regression `test/search_scope_touch_test.dart` checks >=48dp and top/center/bottom taps followed by cancellation, unchanged query/scope. Use mobile `BoxConstraints(minHeight: 48)` while keeping desktop 32px. Native check: `flutter test test/search_scope_touch_test.dart test/workspace_screen_test.dart`.
- [x] #587 / T-041: `search/context_timeline` owns open snapshot freshness. Add controller refresh tests before implementation: edit, immediate delete, late read, revision ordering, initial-read race, wrong conversation/session. Bind the shared component to session-scoped realtime hints. On delete use `{...item, deleted:true, body:'', attachments:[], mentionUserIds:[]}`; protected refresh must merge only loaded IDs with nondecreasing revisions. Check `npm test -- src/search src/workspace` and `npm run build`; rerun the isolated six-counterexample harness if available.
- [x] #589 / FV2-006: attachment viewer must revoke already displayed bytes and actions on its message delete, and discard late reads. Add widget regressions for open→delete, loading→delete, unrelated DM/channel and session replacement. Keep protected download and explicit Retry behavior. Check focused attachment tests and changed-file analysis; physical Samsung acceptance remains separate.
- [ ] #584 / T-SS-FLUTTER: inspect exact screen capture/publish edges and static-frame encoding lifecycle. Preserve first-pass behavior; add a regression only for an established source defect. A physical fast/delayed app-only picker comparison is required to claim first-frame acceptance. Do not invent the root cause from a motion correlation.
- [x] Register all new acceptance scenarios in `tools/qa/local_features/features.json`, run the project feature runner, keep unavailable runtime stages BLOCKED, inspect generated images at source resolution.
- [ ] Inspect diff/status/file sizes, exclude generated plugin files, record evidence and prepare reviewable commits/PR. Do not close device gates using unit tests.

Stop condition: validated source fixes or one concrete blocker per issue, source-bound evidence, and a reviewable branch. Open questions: availability of a controlled physical device and exact QA runner source; #584 capture vs encoder vs subscription root cause.

Current outcome: four source fixes with passing native/unit regressions. #584 remains unresolved; signed instrumented physical runtime and the original real-stack acceptance remain pending. See `evidence/qa/recent-bugs-2026-10-28/README.md` for all failed/blocked checks.
