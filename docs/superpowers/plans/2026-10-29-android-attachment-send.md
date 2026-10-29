# Android attachment send acknowledgement implementation plan

> Agentic execution: follow the tasks inline; the owner retains Git/PR/CI actions.

**Goal:** Keep a confirmed own DM attachment card visible when POST returns a
minimal receipt and realtime delivery is unavailable, without inventing metadata.

**Architecture:** Resolve incomplete attachment acknowledgements through the
existing author/client-scoped delivery lookup and canonical addressed history.
Preserve the receipt across failed readback, fence sessions, and prefer newer
confirmed rows and tombstones. Backend receipt responses remain unchanged.

**Tech stack:** Dart 3.13.5, Flutter 3.47.7, MockClient and flutter_test.

## Source and preservation

- Baseline source: `754b5997ad100cb00300373f29ab88bda4ed267d`.
- Caller: `clients/flutter/lib/src/screens/workspace_ui/direct_conversation/send/handler.dart`.
- API: `clients/flutter/lib/src/features/direct/messages/api.dart`.
- Store: `clients/flutter/lib/src/features/direct/send_state/send.dart`.
- Lookup: `clients/flutter/lib/src/features/conversation/delivery/lookup_api.dart`.
- Models: `clients/flutter/lib/src/models.dart:572`; do not refactor this file.
- Backend minimal receipt is intentional. Native captured POST shape is UNKNOWN;
  the controlled B observation counted zero attachments, including omitted data.
- Preserve existing session/Origin/cookie/ACL, client UUID, retry and #589 viewer
  revocation rules. Do not modify backend, build number, CI policy or old evidence.

## Task 1 — Regression before production changes

Create `clients/flutter/test/direct_send_hydration/fixture.dart` and
`clients/flutter/test/direct_send_hydration/ack_test.dart`.

- [x] Use real DirectMessagesApi parsing with MockClient, AppState ready/owner,
  a selected existing synthetic DM, and no realtime connection.
- [x] POST returns a minimal 201. Existing delivery receipt and addressed GET
  return the same author/client/message/DM with a JPEG or GIF attachment.
- [x] Assert the production state, without manual history refresh:

```dart
expect(await state.sendDirect('', attachments: [file]), isTrue);
expect(state.directMessageHistory.single.attachments.single.id, file.id);
expect(api.posts, 1);
expect(api.historyReads, 1);
```

- [x] Run RED and preserve the actual exit/output before any implementation:
  `flutter test --no-pub --reporter expanded test/direct_send_hydration/`.

## Task 2 — Canonical acceptance and bounded receipt retention

Modify these six production files only:

1. `clients/flutter/lib/src/features/direct/send_state/delivery.dart`: after
   recoverDelivery completes, hydrate incomplete attachment receipts outside its
   catch/retry path. A known successful receipt bypasses POST on manual retry.
2. `clients/flutter/lib/src/features/direct/send_state/hydrate.dart` (new):
   validate exact message/client/author/DM; obtain protected canonical metadata;
   expose checking/failed pending state on failure; never copy draft attachments
   into a confirmed row. Canonical deletion is authoritative.
3. `clients/flutter/lib/src/features/direct/send_state/send.dart`: accept the
   newest matching canonical row/tombstone and remove the retained receipt only
   after success, preserving the original client UUID and composer result.
4. `clients/flutter/lib/src/features/conversation/lifecycle/controller.dart`:
   retain minimal successful direct-send receipts keyed by client UUID.
5. `clients/flutter/lib/src/features/conversation/lifecycle/clear.dart`: clear
   retained receipts with account/session-owned conversation state.
6. `clients/flutter/lib/src/features/direct/edit_state/delete.dart`: discard a
   failed optimistic row's retained receipt with its explicit local removal.

- [x] Keep every changed/new production file <=120 lines; no model refactor.
- [x] The canonical lookup uses the existing owner-verified receipt then
  addressed GET. Require `row.id == ack.id`, matching client UUID, author and DM.
- [x] A failed readback must not report send success or cause a second POST for
  the known committed UUID. An explicit retry checks canonical state again.
- [x] Session invalidation rejects late completion. A matching newer revision
  or deleted cached row wins over a late readback; never restore deleted bytes.
- [x] Canonical readback has a 20-second deadline; an actual uncompleted GET is
  fake-clock tested through failed state, same-UUID checking retry and session fencing.
- [x] Checking writes visible history only while that exact DM remains selected;
  navigation during both POST and hydration preserves the other DM history.

## Task 3 — Guards, rendering and registration

- [x] Add focused files under `test/direct_send_hydration/`, each <=120 lines:
  wrong author/client/message/DM; missing canonical row; readback failure/retry;
  late canonical versus newer row/tombstone; session replacement; text unchanged.
- [x] Render actual MessageAttachmentList after successful send for valid tiny
  synthetic JPEG/GIF contents. Verify filename/open control and decoded image.
- [x] Optional captures are exactly `dm-attachment-send-jpeg.png` and
  `dm-attachment-send-gif.png`; root owns their CI artifact allowlist changes.
- [x] Register source/test/scenario in `tools/qa/local_features/features.json`,
  feature `chat`, keeping native runtime and physical acceptance NOT_RUN.

## Task 4 — Validation and evidence

- [x] Run focused GREEN, then nearest delivery, conversation, attachment and
  unchanged #589 suites. Run format/analyze on changed Dart files.
- [x] `flutter test --no-pub --reporter expanded test/direct_send_hydration/`.
- [x] `flutter test --no-pub --reporter expanded test/delivery_recovery_test.dart test/delivery_lookup_api_test.dart test/app_state_test.dart test/conversation_scope/ test/attachment_revocation_test.dart test/message_attachment_list_test.dart`.
- [ ] `./tools/qa/local_features/check.sh --feature chat --base 754b5997ad100cb00300373f29ab88bda4ed267d --real-stack`.
  NOT_RUN in this code packet; root owns the post-commit runtime command.
- [x] Store logs, source hashes and protects→command→platform→mandatory_when→result
  in `.out/fix598-249-ci/android-send/` in the evidence workspace selected by root.
- [x] Inspect optional captures at source resolution. Report actual tests/skips,
  physical NOT_RUN and known 589 evidence limits. No old FAIL is rewritten.
- [x] Hand off the diff to root without commit, push, PR, dispatch or device work.
