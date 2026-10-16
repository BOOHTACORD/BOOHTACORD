import 'dart:io';

import 'package:boohtacord_desktop/src/widgets/formatted_message_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/desktop_updates/windows_app.dart';

void main() {
  for (final drawer in [false, true]) {
    testWidgets('channel navigation uses the visible UI (drawer: $drawer)', (
      tester,
    ) async {
      var selected = false;
      var opened = 0;
      Widget channel(BuildContext context) => TextButton(
        onPressed: () {
          selected = true;
          if (drawer) Navigator.pop(context);
        },
        child: const Text('Update VOICE'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              leading: Builder(
                builder: (context) => IconButton(
                  tooltip: 'Открыть навигацию',
                  icon: const Icon(Icons.menu),
                  onPressed: () {
                    opened++;
                    Scaffold.of(context).openDrawer();
                  },
                ),
              ),
            ),
            drawer: Drawer(child: Builder(builder: channel)),
            body: drawer ? const SizedBox.shrink() : Builder(builder: channel),
          ),
        ),
      );
      final journey = Journey(Directory.systemTemp, controller: tester);
      await journey.openChannel('Update VOICE', at: 'voice_open');
      await tester.pumpAndSettle();
      expect(selected, isTrue);
      expect(opened, drawer ? 1 : 0);
    });
  }

  testWidgets(
    'driver consents through the visible dialog instead of its covered panel',
    (tester) async {
      var consented = false;
      late BuildContext panelContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              panelContext = context;
              return Scaffold(
                body: FilledButton(
                  onPressed: () {},
                  child: const Text('Перезапустить'),
                ),
              );
            },
          ),
        ),
      );
      showDialog<void>(
        context: panelContext,
        builder: (context) => AlertDialog(
          actions: [
            FilledButton(
              onPressed: () {
                consented = true;
                Navigator.pop(context);
              },
              child: const Text('Перезапустить'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final journey = Journey(Directory.systemTemp, controller: tester);
      await journey.tap(
        find.widgetWithText(FilledButton, 'Перезапустить'),
        at: 'restart_consent',
      );
      await tester.pumpAndSettle();
      expect(consented, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
      expect(journey.step, 'restart_consent');
    },
  );

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
