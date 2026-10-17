import 'dart:async';
import 'dart:io';

import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/services/system_clipboard_paste.dart';
import 'package:boohtacord_desktop/src/widgets/message_attachment_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Dedicated QA simulator only. Native clipboard contents are synthetic; a gate
// holds completion after the real OS read, never the platform channel itself.
// Editing values are controlled here: this does not certify a physical IME.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final scope in ['text', 'dm']) {
    for (final fallback in [false, true]) {
      for (final change in ['selection', 'composing', 'text', 'unchanged']) {
        testWidgets('native $scope clipboard fallback=$fallback $change', (
          tester,
        ) async {
          final state = AppState(ApiClient());
          final controller = TextEditingController.fromValue(
            const TextEditingValue(
              text: 'draft',
              selection: TextSelection.collapsed(offset: 2),
            ),
          );
          final focus = FocusNode();
          final read = Completer<void>();
          final release = Completer<void>();
          final key = GlobalKey<MessageAttachmentComposerState>();
          addTearDown(() async {
            if (!release.isCompleted) release.complete();
            await tester.pumpWidget(const SizedBox.shrink());
            state.dispose();
            controller.dispose();
            focus.dispose();
          });
          await tester.runAsync(
            () => Clipboard.setData(const ClipboardData(text: 'QA-paste')),
          );
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                appBar: AppBar(title: Text('Clipboard QA · $scope')),
                body: Column(
                  children: [
                    // Keep the OS keyboard from asynchronously rewriting the
                    // controlled composing/selection fixture after our check.
                    TextField(
                      controller: controller,
                      focusNode: focus,
                      readOnly: true,
                    ),
                    MessageAttachmentComposer(
                      key: key,
                      state: state,
                      attachments: const [],
                      onChanged: (_) {},
                      onPending: (_) {},
                      textController: controller,
                      focusNode: focus,
                      channelId: scope == 'text' ? 'qa-channel' : null,
                      directMessageId: scope == 'dm' ? 'qa-dm' : null,
                      clipboardReader: () async {
                        final content = await readSystemClipboardPaste();
                        expect(content?.text, 'QA-paste');
                        read.complete();
                        await release.future;
                        // Null exercises the real Flutter Clipboard fallback.
                        return fallback ? null : content;
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (Platform.isAndroid) {
            await binding.convertFlutterSurfaceToImage();
            await tester.pumpAndSettle();
          }
          late Future<void> paste;
          await tester.runAsync(() async {
            paste = key.currentState!.pasteFromClipboard();
            await read.future.timeout(const Duration(seconds: 15));
          });
          switch (change) {
            case 'selection':
              controller.selection = const TextSelection(
                baseOffset: 4,
                extentOffset: 1,
                affinity: TextAffinity.upstream,
                isDirectional: true,
              );
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
          final latest = controller.value;
          await tester.runAsync(() async {
            release.complete();
            await paste.timeout(const Duration(seconds: 15));
          });
          await tester.pumpAndSettle();
          expect(
            controller.value,
            change == 'unchanged'
                ? const TextEditingValue(
                    text: 'drQA-pasteaft',
                    selection: TextSelection.collapsed(offset: 10),
                  )
                : latest,
          );
          expect(tester.takeException(), isNull);
          if (!fallback && ['selection', 'unchanged'].contains(change)) {
            focus.unfocus();
            await tester.pumpAndSettle();
            await binding.takeScreenshot('clipboard-$scope-$change');
          }
        });
      }
    }
  }
}
