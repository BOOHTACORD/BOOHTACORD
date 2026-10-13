import 'dart:convert';

import 'package:boohtacord_desktop/src/screens/screen_receiver_diagnostics.dart';
import 'package:boohtacord_desktop/src/features/screen/sender_metadata/latest_writer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('labels mode and requested profile as sender metadata', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_descriptor()));
    await tester.tap(find.text('Статистика'));
    await tester.pumpAndSettle();

    expect(find.text('Режим отправителя'), findsOneWidget);
    expect(find.text('Плавность'), findsOneWidget);
    expect(find.text('Выбрано отправителем'), findsOneWidget);
    expect(find.text('1080p · 60 FPS'), findsOneWidget);
    expect(find.text('Сейчас у зрителя'), findsOneWidget);
    final viewerRow = find.ancestor(
      of: find.text('Сейчас у зрителя'),
      matching: find.byType(Row),
    );
    expect(
      find.descendant(of: viewerRow, matching: find.text('Нет данных')),
      findsOneWidget,
    );
  });

  testWidgets('keeps legacy track diagnostics and omits invented sender data', (
    tester,
  ) async {
    await tester.pumpWidget(_app(null, trackName: 'screenshare-720p-15fps'));
    await tester.tap(find.text('Статистика'));
    await tester.pumpAndSettle();

    expect(find.text('Профиль при запуске'), findsOneWidget);
    expect(find.text('720p · 15 FPS'), findsOneWidget);
    expect(find.text('Режим отправителя'), findsOneWidget);
    expect(find.text('Нет данных от отправителя'), findsNWidgets(2));
  });

  testWidgets(
    'renders confirmed configuration separately from absent sender measurements',
    (tester) async {
      await tester.pumpWidget(_app(_descriptor()));
      await tester.tap(find.text('Статистика'));
      await tester.pumpAndSettle();
      expect(find.text('Лимиты захвата SDK'), findsOneWidget);
      expect(find.text('1920 × 1080 · до 60 FPS'), findsOneWidget);
      expect(
        find.text('SDK отправителя · лимиты, не измеренный FPS'),
        findsOneWidget,
      );
      expect(find.text('Возраст захвата неизвестен'), findsOneWidget);
      final senderMeasurement = find.ancestor(
        of: find.text('Измерено у отправителя'),
        matching: find.byType(Row),
      );
      expect(
        find.descendant(
          of: senderMeasurement,
          matching: find.text('Нет данных'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'changed publication hint does not keep previous configuration current',
    (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        _app(_descriptor(), key: key, trackName: 'screenshare-1080p-60fps'),
      );
      await tester.pumpWidget(
        _app(_descriptor(), key: key, trackName: 'screenshare-720p-30fps'),
      );
      await tester.tap(find.text('Статистика'));
      await tester.pumpAndSettle();
      expect(
        find.text('SDK отправителя · лимиты, не измеренный FPS'),
        findsNothing,
      );
      expect(find.text('Источник конфигурации неизвестен'), findsOneWidget);
      expect(find.text('720p · 30 FPS'), findsOneWidget);
    },
  );

  testWidgets('local pending update labels retained SDK limits as previous', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScreenReceiverDiagnostics(
            track: null,
            isLocal: true,
            hasAudio: false,
            senderDescriptorJson: _descriptor(),
            senderSelectedProfileId: 'P720_30',
            senderSelectedMode: 'motion',
            senderConfigurationStatus: ScreenDescriptorWriteStatus.pending,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Статистика'));
    await tester.pumpAndSettle();
    expect(find.text('720p · 30 FPS'), findsOneWidget);
    expect(find.text('Ожидается подтверждение'), findsOneWidget);
    expect(find.text('Предыдущие лимиты захвата SDK'), findsOneWidget);
    expect(find.text('1920 × 1080 · до 60 FPS'), findsOneWidget);
    expect(find.text('Подтверждено в SDK'), findsNothing);
  });

  testWidgets(
    'local SDK confirmation and server acknowledgement have distinct labels',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScreenReceiverDiagnostics(
              track: null,
              isLocal: true,
              hasAudio: false,
              senderDescriptorJson: _descriptor(),
              senderSelectedProfileId: 'P1080_60',
              senderSelectedMode: 'text',
              senderConfigurationStatus: ScreenDescriptorWriteStatus.applied,
              senderConfirmedAt: DateTime(2026, 10, 13, 12, 0, 1),
              senderAppliedAt: DateTime(2026, 10, 13, 12, 0, 2),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Статистика'));
      await tester.pumpAndSettle();
      expect(find.text('Чёткость текста'), findsOneWidget);
      expect(find.text('Записано сервером'), findsOneWidget);
      expect(find.text('Подтверждено в SDK'), findsOneWidget);
      expect(find.text('Записано сервером в'), findsOneWidget);
      expect(find.text('12:00:01'), findsOneWidget);
      expect(find.text('12:00:02'), findsOneWidget);
    },
  );

  testWidgets(
    'local chosen 60 FPS stays available before any configuration readback',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ScreenReceiverDiagnostics(
              track: null,
              isLocal: true,
              hasAudio: false,
              senderSelectedProfileId: 'P1080_60',
              senderSelectedMode: 'motion',
              senderConfigurationStatus: ScreenDescriptorWriteStatus.pending,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Статистика'));
      await tester.pumpAndSettle();
      expect(find.text('1080p · 60 FPS'), findsOneWidget);
      expect(find.text('Ожидается подтверждение'), findsOneWidget);
      expect(find.text('Источник конфигурации неизвестен'), findsOneWidget);
      expect(find.text('0 FPS'), findsNothing);
    },
  );

  testWidgets(
    'previous confirmed 30 FPS never replaces current chosen 60 FPS',
    (tester) async {
      final previous = jsonDecode(_descriptor()) as Map<String, dynamic>;
      previous['effective_profile']['capture']['max_fps'] = 30;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScreenReceiverDiagnostics(
              track: null,
              isLocal: true,
              hasAudio: false,
              senderDescriptorJson: jsonEncode(previous),
              senderSelectedProfileId: 'P1080_60',
              senderSelectedMode: 'text',
              senderConfigurationStatus: ScreenDescriptorWriteStatus.pending,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Статистика'));
      await tester.pumpAndSettle();
      expect(find.text('1080p · 60 FPS'), findsOneWidget);
      expect(find.text('1920 × 1080 · до 30 FPS'), findsOneWidget);
      expect(find.text('Предыдущие лимиты захвата SDK'), findsOneWidget);
      expect(find.text('Ожидается подтверждение'), findsOneWidget);
    },
  );

  testWidgets('new publication SID rejects late old-generation revisions', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      _app(_descriptor(revision: 8), key: key, publicationKey: 'old-pub'),
    );
    await tester.pumpWidget(
      _app(_descriptor(revision: 9), key: key, publicationKey: 'new-pub'),
    );
    await tester.tap(find.text('Статистика'));
    await tester.pumpAndSettle();
    expect(
      find.text('SDK отправителя · лимиты, не измеренный FPS'),
      findsNothing,
    );
    await tester.pumpWidget(
      _app(_descriptor(revision: 10), key: key, publicationKey: 'new-pub'),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('SDK отправителя · лимиты, не измеренный FPS'),
      findsNothing,
    );
    await tester.pumpWidget(
      _app(
        _descriptor(generation: 5, revision: 1),
        key: key,
        publicationKey: 'new-pub',
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('SDK отправителя · лимиты, не измеренный FPS'),
      findsOneWidget,
    );
  });

  testWidgets('ignores an out-of-order descriptor revision', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(_app(_descriptor(revision: 8), key: key));
    await tester.pumpWidget(_app(_descriptor(revision: 7), key: key));
    await tester.tap(find.text('Статистика'));
    await tester.pumpAndSettle();

    expect(find.text('Выбрано отправителем'), findsOneWidget);
    expect(find.text('1080p · 60 FPS'), findsOneWidget);
  });
}

Widget _app(
  String? descriptor, {
  String? trackName,
  String? publicationKey,
  Key? key,
}) => MaterialApp(
  home: Scaffold(
    body: ScreenReceiverDiagnostics(
      key: key,
      publicationKey: publicationKey,
      track: null,
      isLocal: false,
      hasAudio: false,
      senderDescriptorJson: descriptor,
      expectedSenderOrigin: 'https://voice.example.test',
      expectedSenderAccountId: 'account-a',
      expectedRoomId: 'room-a',
      sourceTrackName: trackName,
    ),
  ),
);

String _descriptor({int revision = 8, int generation = 4}) => jsonEncode({
  'schema_version': 1,
  'scope': {
    'origin_id': 'https://voice.example.test',
    'account_id': 'account-a',
    'room_id': 'room-a',
    'media_session_id': 'session-a',
    'publication_generation': generation,
    'operation_revision': revision,
  },
  'mode': 'motion',
  'publisher_state': 'sharing',
  'viewer_state': 'idle',
  'requested_profile_id': 'P1080_60',
  'effective_profile': {
    'capture': {'max_width': 1920, 'max_height': 1080, 'max_fps': 60},
    'encoding': {
      'codec': null,
      'layers': [
        {
          'rid': null,
          'width': 1920,
          'height': 1080,
          'max_fps': 60,
          'max_bitrate_bps': 8000000,
          'scale_down_by': 1,
          'active': true,
        },
      ],
    },
  },
  'layer_topology': 'single-layer',
  'profile_revision': 1,
  'capabilities': {
    'live_update': true,
    'republish_without_recapture': false,
    'simulcast': false,
  },
  'reason_codes': ['user-request'],
});
