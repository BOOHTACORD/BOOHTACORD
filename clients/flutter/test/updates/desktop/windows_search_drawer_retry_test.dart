import 'dart:io';

import 'package:boohtacord_desktop/src/features/workspace/mobile_navigation/search_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/desktop_updates/windows_app.dart';

class ClosingDrawerJourney extends Journey {
  ClosingDrawerJourney(
    super.output,
    WidgetController controller,
    this.close,
    this.resets,
  ) : super(controller: controller);

  final VoidCallback close;
  final int resets;
  var openings = 0;

  @override
  Future<void> tap(Finder finder, {required String at}) async {
    if (at == 'search_open' && finder.hitTestable().evaluate().isEmpty) {
      throw StateError('control_missing');
    }
    await super.tap(finder, at: at);
    if (at == 'navigation_open' && ++openings <= resets) {
      close();
      await driver.pump();
    }
  }
}

void main() {
  for (final resets in [1, 3]) {
    testWidgets('voice search handles $resets drawer closures', (tester) async {
      var drawer = false, search = false, navigation = false, selected = false;
      late VoidCallback close;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, update) {
              close = () => update(() => drawer = false);
              return Scaffold(
                body: Column(
                  children: [
                    if (!drawer && !search)
                      IconButton(
                        tooltip: 'Открыть навигацию',
                        onPressed: () => update(() => drawer = true),
                        icon: const Icon(Icons.menu),
                      ),
                    if (drawer)
                      WorkspaceNavigationSearch(
                        compact: true,
                        onPressed: () => update(() {
                          drawer = false;
                          search = true;
                        }),
                      ),
                    if (search && !navigation)
                      IconButton(
                        tooltip: 'Каналы и люди',
                        onPressed: () => update(() => navigation = true),
                        icon: const Icon(Icons.people),
                      ),
                    if (search && navigation)
                      ListTile(
                        key: const ValueKey('guild-quick-jump-results'),
                        title: const Text('Update VOICE'),
                        onTap: () => update(() => selected = true),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      final journey = ClosingDrawerJourney(
        Directory.systemTemp,
        tester,
        close,
        resets,
      );
      if (resets == 1) {
        await journey.openVoiceWithoutJoining('Update VOICE');
        expect(journey.openings, 2);
        expect(selected, isTrue);
      } else {
        await expectLater(
          journey.openVoiceWithoutJoining('Update VOICE'),
          throwsStateError,
        );
        expect(journey.openings, 3);
        expect(selected, isFalse);
      }
    });
  }
}
