import 'dart:io';

import 'package:boohtacord_desktop/src/widgets/formatted_message_body.dart';
import 'package:boohtacord_desktop/src/features/workspace/mobile_navigation/search_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/desktop_updates/windows_app.dart';

void main() {
  testWidgets(
    'installed acceptance waits for the real delayed message anchor',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
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
        ),
      );
      final journey = Journey(Directory.systemTemp, controller: tester);
      expect(journey.anchor()['ordinal'], 50);
      Future<void>.delayed(
        const Duration(milliseconds: 250),
        () => scroll.jumpTo(60),
      );
      await journey.waitForRestoredAnchor({
        'ordinal': 51,
        'top': -10,
      }, timeout: const Duration(seconds: 2));
      expect(journey.anchor(), {'ordinal': 51, 'top': -10});
      expect(journey.restorationObservedAnchor, {'ordinal': 51, 'top': -10});
      // A subpixel change can hide the last fraction of the old first row.
      // Compare that same message's offset, rather than selecting a different
      // first-visible message and incorrectly rejecting a <2 px restoration.
      scroll.jumpTo(49.5);
      await tester.pump();
      final boundaryAnchor = journey.anchor();
      expect(boundaryAnchor, {'ordinal': 50, 'top': -49.5});
      scroll.jumpTo(50);
      await tester.pump();
      expect(journey.anchor()['ordinal'], 51);
      await journey.waitForRestoredAnchor(
        boundaryAnchor,
        timeout: const Duration(seconds: 2),
      );
      expect(journey.restorationObservedAnchor, {'ordinal': 50, 'top': -50});
      Object? rejected;
      try {
        await journey.waitForRestoredAnchor({
          'ordinal': 55,
          'top': 0,
        }, timeout: Duration.zero);
      } catch (error) {
        rejected = error;
      }
      expect(rejected, isStateError);
      expect(scroll.offset, 50); // The acceptance observer never moves the list.
    },
  );

  for (final drawer in [false, true]) {
    testWidgets(
      'voice prejoin uses quick jump without drawer autojoin ($drawer)',
      (tester) async {
        var search = false, navigation = false;
        var selected = 0, autoJoined = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, update) {
                Widget sidebar(BuildContext context) => Column(
                  children: [
                    WorkspaceNavigationSearch(
                      compact: drawer,
                      onPressed: () {
                        if (drawer) Navigator.pop(context);
                        update(() => search = true);
                      },
                    ),
                    TextButton(
                      onPressed: () => autoJoined++,
                      child: const Text('Update VOICE'),
                    ),
                  ],
                );
                return Scaffold(
                  appBar: AppBar(
                    leading: Builder(
                      builder: (context) => IconButton(
                        tooltip: 'Открыть навигацию',
                        icon: const Icon(Icons.menu),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                  ),
                  drawer: Drawer(child: Builder(builder: sidebar)),
                  body: search
                      ? Column(
                          children: [
                            IconButton(
                              tooltip: 'Каналы и люди',
                              onPressed: () => update(() => navigation = true),
                              icon: const Icon(Icons.people),
                            ),
                            if (navigation)
                              Expanded(
                                child: ListView(
                                  key: const ValueKey(
                                    'guild-quick-jump-results',
                                  ),
                                  children: [
                                    ListTile(
                                      title: const Text('Update VOICE'),
                                      subtitle: const Text(
                                        'Открыть комнату без подключения',
                                      ),
                                      onTap: () => update(() {
                                        selected++;
                                        search = false;
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        )
                      : drawer
                      ? const SizedBox.shrink()
                      : Builder(builder: sidebar),
                );
              },
            ),
          ),
        );
        await Journey(
          Directory.systemTemp,
          controller: tester,
        ).openVoiceWithoutJoining('Update VOICE');
        await tester.pumpAndSettle();
        expect(selected, 1);
        expect(autoJoined, 0);
      },
    );
  }

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
