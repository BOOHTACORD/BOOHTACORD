import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/widgets/message_attachment_composer.dart';

Future<void> verifyPublicSupportBridge(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  AppState state,
  ApiClient api,
  String pair,
  String marker,
) async {
  expect(
    RegExp(r'^Synthetic BOOHTACORD public bridge QA [a-f0-9]{16}$')
        .hasMatch(marker),
    isTrue,
  );
  // Synthetic native API upload; the system picker is deliberately outside this proof.
  final file = await tester.runAsync(
    () => api.uploadDirectMessageAttachment(
      pair,
      'synthetic-public-support.txt',
      Uint8List.fromList(utf8.encode('Synthetic public support QA file\n')),
    ),
  );
  expect(file, isNotNull);
  tester
      .widget<MessageAttachmentComposer>(find.byType(MessageAttachmentComposer))
      .onChanged([file!]);
  await tester.pump(const Duration(milliseconds: 500));
  final composer = find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == 'Написать сообщение…',
  );
  await tester.enterText(composer, marker);
  await tester.pump();
  await tester.tap(find.byTooltip('Отправить личное сообщение'));
  for (
    var i = 0;
    i < 120 &&
        (state.sending ||
            !state.directMessageHistory.any((m) => m.body == marker));
    i++
  ) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(state.directMessageHistory.any((m) => m.body == marker), isTrue);
  expect(state.sending, isFalse);
  await tester.pump(const Duration(milliseconds: 500));
  // A separate host process performs the bounded operator action. No credential enters the device.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 500));
  await binding.takeScreenshot('native-public-support-sent');
  const response = 'Synthetic BOOHTACORD public bridge operator reply';
  for (
    var i = 0;
    i < 480 && !state.directMessageHistory.any((m) => m.body == response);
    i++
  ) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(state.directMessageHistory.any((m) => m.body == response), isTrue);
  await tester.pump(const Duration(milliseconds: 500));
  await binding.takeScreenshot('native-public-support-replied');
  expect(tester.takeException(), isNull);
}
