# Issue #598: own attachment Send canonical hydration

Baseline: `754b5997ad100cb00300373f29ab88bda4ed267d`; results bind the working diff.
Flutter 3.47.7 / Dart 3.13.5, framework `abaf9c523780a608bd46686fd5e53740a07077f8`.
Host: Windows, headless Flutter; widget target Android, 390×844 logical/source pixels.
This is implementation/unit/widget evidence. Signed physical acceptance is **NOT_RUN**.

## Cause and change

The existing DM POST response is a minimal receipt. `DirectChatMessage.fromJson`
turns omitted attachment metadata into an empty list; Send previously replaced
its fully populated optimistic row with that receipt. Native production POST
bytes were not captured. The controlled B receipt counted zero attachment items;
omitted versus an explicit empty list remains unobserved in that older receipt.

Incomplete attachment receipts now use the existing author/client-scoped receipt
lookup and protected addressed canonical history. Message ID, client UUID, author
and DM must match. Confirmed metadata is never copied from the pending draft.
A known successful receipt survives failed readback, so manual checking retry
never repeats POST. Canonical lookup has a 20-second deadline. Newer confirmed
revisions/tombstones win; late session and other-DM writes are fenced.
Account cleanup and explicit failed-row discard remove retained receipts.
Body-only direct sends and the backend receipt/ACL contracts remain unchanged.

## Actual commands

`T115`, from `clients/flutter`:

```sh
flutter test --no-pub --reporter expanded \
  test/direct_send_hydration/ \
  test/delivery_recovery_test.dart test/delivery_lookup_api_test.dart \
  test/delivery_status_widget_test.dart test/app_state_test.dart \
  test/conversation_scope/ test/attachment_revocation_test.dart \
  test/message_attachment_list_test.dart test/message_attachment_composer_test.dart
```

`A`, from `clients/flutter`:

```sh
flutter analyze --no-pub lib/src/features/direct/send_state \
  lib/src/features/conversation/lifecycle/controller.dart \
  lib/src/features/conversation/lifecycle/clear.dart \
  lib/src/features/direct/edit_state/delete.dart test/direct_send_hydration
```

| Invariant protected | Command | Platform | Mandatory when | Actual result |
| --- | --- | --- | --- | --- |
| Minimal 201 must retain own JPEG/GIF metadata without realtime or manual history refresh | T115; ack/widget cases | Flutter/Windows, Android widget target | Accepting #598 Send behavior | PASS; focused 24 cases included in 115 passed, 0 skipped; exit 0 |
| Exact owner/message/client/DM correlation, navigation and newer/tombstone/session fences | T115; guard/race/navigation cases | Same | Accepting canonical data into store | PASS |
| Never-completing GET ends checking; retry does not repost known201; late completion fenced | T115; deadline/retry cases | Fake clock + actual uncompleted HTTP future | Accepting readback/retry | PASS; fake 21s advance, failed/sending=false, 1 POST |
| Existing delivery, composer and #589 revocation behavior | T115; nearest suites | Same | Preserving prior behavior | PASS; 115 total / 0 skipped |
| Dart source quality | A; dart format --output=none --set-exit-if-changed on six source files + test folder | Pinned SDK | Before handoff | PASS; no analyze issues, 15 files already formatted |
| Registered chat source/scenario and exact capture names | python -X utf8 -m unittest tools.qa.local_features.test_policy | Windows/Python | Before feature handoff | PASS 4 tests; changed source coverage is chat |
| Owned real stack/native runtime | tools/qa/local_features/check.sh --feature chat --base 754b5997ad100cb00300373f29ab88bda4ed267d --real-stack | Dedicated QA runtimes | Runtime acceptance | NOT_RUN here; root owns post-commit check |
| New signed Android candidate, actual file picker/Send/peer bytes/delete | Separate authorized physical packet | Samsung Android | Physical acceptance | NOT_RUN; old physical FAIL evidence remains unchanged |

## RED and final log bindings

- First behavioral RED before the fix: 4 failed JPG/GIF × omitted/empty-ACK cases;
  actual exit 1, expected attachment item versus actual empty list.
  stdout SHA256 `87660e666aaee48f029019b3cac5002bcb5dd7fb854b358cd6031af48a32a87d`.
- Deadline RED before adding timeout: 1 failure, sending remained true after fake21s;
  actual exit 1. stdout SHA256 `10a2f18b436aeafd55c70a3aec32f1520ca2e729ffd399874af402b1acba5daa`.
- Final T115: exit0, 115 passed, 0 skipped, scoped raw sources unchanged during run.
  stdout SHA256 `81b002ba5ba138701efedccda07fe28b76ef628bc942cb9f847536b1d6bad78e`.
- Final A: exit0. stdout SHA256 `fb9ebe7d946c6b4b62b11f5914f99d3d30a6e4b280a3cc31b67f9648c2922162`.
- An initial no-package-config run was infrastructure BLOCKED before compilation;
  normal `flutter pub get --enforce-lockfile` succeeded with unchanged lock bytes.
  Early capture frames before asynchronous image paint are preserved as diagnostics;
  final widget tests require a decoded painted image before capture.

## Synthetic visual review

Actual production WorkspaceDirectConversation: completed-upload metadata staged,
then its explicit Send button used. No websocket is connected. Actual own rows
show colored protected previews, filenames/sizes/open/download controls and an
empty composer without a pending chip. Both 390×844 captures were inspected at
source resolution by the implementing agent and independently by root; no clipping
was observed. JPEG decodes one frame, GIF two; animation acceptance is not claimed.

- `dm-attachment-send-jpeg.png`: `0dc9132de029e533fb7280b45592923ffe0fa1794881471afaa02bc4b0dcd3bd`.
- `dm-attachment-send-gif.png`: `bcbe58590608cdc8da92149d56a8d9afb2488edb703f2024decdae6f0bfefca4`.

## Source hash scheme and limits

[issue598-attachment-send-hydration-2026-10-29-source-hashes.json](issue598-attachment-send-hydration-2026-10-29-source-hashes.json) records separate exact raw Windows working-copy
SHA256 and portable CRLF→LF content SHA256 maps. Git staging with autocrlf may
normalize line endings; raw file hashes are not Git blob IDs. No source rewrite or
runtime rerun was performed solely to force raw/LF hash equality.
The unchanged #589 viewer/list/test normalized hashes are retained there too.
No production calls, device actions, native cookie extraction, permission/media
changes or raw private DM data are part of this code packet. Component captures
are supplemental; prior physical failures and strict #589 proof limits remain.
