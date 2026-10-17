// Operator-authored regressions for the local-model implementation/review exercise.
import 'dart:async';

import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/services/system_clipboard_paste.dart';
import 'package:boohtacord_desktop/src/widgets/message_attachment_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final scope in ['text', 'dm']) {
    for (final fallback in [false, true]) {
      for (final change in ['selection', 'composing', 'text', 'unchanged']) {
        testWidgets(
          'pending $scope paste fallback=$fallback preserves $change',
          (tester) async {
            FlutterSecureStorage.setMockInitialValues({});
            final state = AppState(
              ApiClient(
                client: MockClient((_) async {
                  throw StateError('Text paste must not perform HTTP requests');
                }),
              ),
            );
            final controller = TextEditingController.fromValue(
              const TextEditingValue(
                text: 'draft',
                selection: TextSelection.collapsed(offset: 2),
              ),
            );
            final focus = FocusNode();
            final native = Completer<ClipboardPasteContent?>();
            final platform = Completer<Map<String, Object?>>();
            var fallbackRequested = false;
            final messenger = TestDefaultBinaryMessengerBinding
                .instance
                .defaultBinaryMessenger;
            messenger.setMockMethodCallHandler(SystemChannels.platform, (
              call,
            ) async {
              if (call.method == 'Clipboard.getData') {
                fallbackRequested = true;
                return platform.future;
              }
              return null;
            });
            addTearDown(() async {
              await tester.pumpWidget(const SizedBox.shrink());
              state.dispose();
              controller.dispose();
              focus.dispose();
              messenger.setMockMethodCallHandler(SystemChannels.platform, null);
            });
            final key = GlobalKey<MessageAttachmentComposerState>();
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: MessageAttachmentComposer(
                    key: key,
                    state: state,
                    channelId: scope == 'text' ? 'synthetic-channel' : null,
                    directMessageId: scope == 'dm' ? 'synthetic-dm' : null,
                    textController: controller,
                    focusNode: focus,
                    clipboardReader: () => native.future,
                    attachments: const [],
                    onChanged: (_) {},
                    onPending: (_) {},
                  ),
                ),
              ),
            );
            final paste = key.currentState!.pasteFromClipboard();
            if (fallback) {
              native.complete(null);
              await tester.pump();
              expect(fallbackRequested, isTrue);
            }
            switch (change) {
              case 'selection':
                controller.selection = const TextSelection.collapsed(offset: 4);
              case 'composing':
                controller.value = controller.value.copyWith(
                  composing: const TextRange(start: 0, end: 2),
                );
              case 'text':
                controller.value = const TextEditingValue(
                  text: 'draft+',
                  selection: TextSelection.collapsed(offset: 6),
                );
              case 'unchanged':
                break;
            }
            final latestValue = controller.value;
            if (fallback) {
              platform.complete({'text': 'PASTE'});
            } else {
              native.complete(const ClipboardPasteContent(text: 'PASTE'));
            }
            await paste;
            await tester.pump();
            expect(
              controller.value,
              change == 'unchanged'
                  ? const TextEditingValue(
                      text: 'drPASTEaft',
                      selection: TextSelection.collapsed(offset: 7),
                    )
                  : latestValue,
            );
            expect(
              find.text(
                'Не удалось прочитать буфер обмена. Повторите попытку.',
              ),
              findsNothing,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
