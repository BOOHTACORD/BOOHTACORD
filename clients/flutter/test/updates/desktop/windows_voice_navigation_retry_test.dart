import 'dart:io';

import 'package:boohtacord_desktop/src/features/workspace/mobile_navigation/search_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/desktop_updates/windows_app.dart';

class ResettingJourney extends Journey {
  ResettingJourney(
    Directory output,
    WidgetController controller,
    this.reset,
    this.resets,
  ) : super(output, controller: controller);

  final VoidCallback reset;
  final int resets;
  var switches = 0;

  @override
  Future<void> tap(Finder finder, {required String at}) async {
    if (at == 'voice_open' && finder.hitTestable().evaluate().isEmpty) {
      throw StateError('control_missing');
    }
    await super.tap(finder, at: at);
    if (at == 'quick_jump_open' && ++switches <= resets) {
      reset();
      await driver.pump();
    }
  }
}

void main() {
  for (final resets in [1, 3]) {
    testWidgets('voice navigation handles $resets panel resets', (
      tester,
    ) async {
      var search = false, navigation = false, selected = false;
      late VoidCallback reset;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, update) {
              reset = () => update(() => navigation = false);
              return Scaffold(
                body: search
                    ? Column(
                        children: [
                          if (!navigation)
                            IconButton(
                              tooltip: 'Каналы и люди',
                              onPressed: () => update(() => navigation = true),
                              icon: const Icon(Icons.people),
                            ),
                          if (navigation)
                            ListTile(
                              key: const ValueKey('guild-quick-jump-results'),
                              title: const Text('Update VOICE'),
                              onTap: () => update(() => selected = true),
                            ),
                        ],
                      )
                    : WorkspaceNavigationSearch(
                        compact: false,
                        onPressed: () => update(() => search = true),
                      ),
              );
            },
          ),
        ),
      );
      final journey = ResettingJourney(
        Directory.systemTemp,
        tester,
        reset,
        resets,
      );
      if (resets == 1) {
        await journey.openVoiceWithoutJoining('Update VOICE');
        expect(journey.switches, 2);
        expect(selected, isTrue);
      } else {
        await expectLater(
          journey.openVoiceWithoutJoining('Update VOICE'),
          throwsStateError,
        );
        expect(journey.switches, 3);
        expect(selected, isFalse);
      }
    });
  }
}
