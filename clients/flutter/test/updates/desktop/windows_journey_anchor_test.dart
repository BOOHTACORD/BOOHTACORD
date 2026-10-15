import 'dart:io';

import 'package:boohtacord_desktop/src/widgets/formatted_message_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/desktop_updates/windows_app.dart';

void main() {
  testWidgets('anchor uses visible rows and ignores cached offscreen rows', (
    tester,
  ) async {
    final scroll = ScrollController(initialScrollOffset: 60);
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            key: const ValueKey('text-channel-messages'),
            height: 100,
            child: ListView(
              controller: scroll,
              itemExtent: 50,
              children: [
                for (var i = 0; i < 6; i++)
                  FormattedMessageBody(
                    body: 'Update history row ${50 + i}',
                    color: Colors.black,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final position = Journey(Directory.systemTemp).anchor();
    expect(position['ordinal'], 51);
    expect(position['top'], -10);
  });

  testWidgets('Windows acceptance measures the actual rich message body', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            key: ValueKey('text-channel-messages'),
            height: 200,
            child: FormattedMessageBody(
              body: 'Update history row 54',
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
    final position = Journey(Directory.systemTemp).anchor();
    expect(position['ordinal'], 54);
    expect(position['top'], 0);
  });
}
