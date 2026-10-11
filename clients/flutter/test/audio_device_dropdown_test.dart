import 'dart:ui' show SemanticsAction, Tristate;

import 'package:boohtacord_desktop/src/screens/workspace_ui/audio_device_dropdown/component.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' show MediaDevice;

void main() {
  testWidgets('truncated device label keeps its full text in semantics', (
    tester,
  ) async {
    const fullLabel =
        'USB Headset — Bluetooth Stereo Hands-Free Audio Device 4f91';
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkspaceAudioDeviceDropdown(
            label: 'Микрофон',
            devices: const [
              MediaDevice('device-4f91', fullLabel, 'audioinput', null),
            ],
            selectedId: 'device-4f91',
            switching: false,
            emptyLabel: 'Нет доступных устройств',
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final selected = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('audio-device-control-Микрофон')),
        matching: find.text(fullLabel),
      ).first,
    );
    expect(selected.overflow, TextOverflow.ellipsis);
    expect(selected.semanticsLabel, fullLabel);
    expect(tester.takeException(), isNull);
  });

  testWidgets('audio device selection exposes semantics and works by keyboard', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final precedingFocus = FocusNode(debugLabel: 'before-audio-device');
    addTearDown(precedingFocus.dispose);
    String? selectedId;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TextButton(
                focusNode: precedingFocus,
                autofocus: true,
                onPressed: () {},
                child: const Text('До выбора устройства'),
              ),
              WorkspaceAudioDeviceDropdown(
                label: 'Микрофон',
                devices: const [
                  MediaDevice('mic-one', 'USB микрофон один', 'audioinput', null),
                  MediaDevice('mic-two', 'USB микрофон два', 'audioinput', null),
                ],
                selectedId: 'mic-one',
                switching: false,
                emptyLabel: 'Нет доступных устройств',
                onChanged: (id) => selectedId = id,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final dropdown = find.byType(DropdownButton<String>);
    final data = tester.getSemantics(dropdown).getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.flagsCollection.isExpanded, Tristate.isFalse);
    expect(data.label, contains('USB микрофон один'));
    expect(data.hasAction(SemanticsAction.tap), isTrue);

    expect(precedingFocus.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(find.text('USB микрофон два'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(selectedId, 'mic-two');
    semantics.dispose();
  });
}
