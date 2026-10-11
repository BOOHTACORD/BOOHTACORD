import 'package:boohtacord_desktop/src/widgets/voice_connection_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' show ConnectionQuality;

void main() {
  testWidgets('announces reconnecting without claiming the room is connected', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VoiceConnectionBadge(
            status: VoiceConnectionBadgeStatus.reconnecting,
          ),
        ),
      ),
    );

    expect(find.text('Восстанавливаем связь'), findsOneWidget);
    expect(find.text('Подключено'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.liveRegion == true &&
            widget.properties.label ==
                'Восстанавливаем голосовое соединение',
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VoiceConnectionBadge(
            status: VoiceConnectionBadgeStatus.connected,
          ),
        ),
      ),
    );
    expect(find.text('Подключено'), findsOneWidget);
    expect(find.text('Восстанавливаем связь'), findsNothing);
    semantics.dispose();
  });

  testWidgets('shows connection quality and measured ping', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VoiceConnectionBadge(
            status: VoiceConnectionBadgeStatus.connected,
            quality: ConnectionQuality.excellent,
            pingMs: 42,
          ),
        ),
      ),
    );

    expect(find.text('Подключено'), findsOneWidget);
    expect(find.text('42 мс'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.liveRegion == true &&
            widget.properties.label == 'Подключено',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.liveRegion != true &&
            widget.properties.label ==
                'Качество соединения: Отличное · ping 42 мс',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('shows unavailable RTT without inventing a ping', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VoiceQualityIndicator(
            quality: ConnectionQuality.good,
            pingMs: null,
          ),
        ),
      ),
    );

    expect(find.text('—'), findsOneWidget);
    expect(find.text('0 мс'), findsNothing);
  });

  testWidgets('announces joining without claiming connection or quality', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VoiceConnectionBadge(
            status: VoiceConnectionBadgeStatus.connecting,
            quality: ConnectionQuality.excellent,
            pingMs: 42,
          ),
        ),
      ),
    );

    expect(find.text('Подключаемся'), findsOneWidget);
    expect(find.text('Подключено'), findsNothing);
    expect(find.text('42 мс'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.liveRegion == true &&
            widget.properties.label == 'Подключаемся к голосовому каналу',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('announces leaving without claiming the room is connected', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VoiceConnectionBadge(
            status: VoiceConnectionBadgeStatus.leaving,
          ),
        ),
      ),
    );

    expect(find.text('Завершаем'), findsOneWidget);
    expect(find.text('Подключено'), findsNothing);
    expect(find.byType(VoiceQualityIndicator), findsNothing);
  });

  testWidgets('announces disconnected and failed states without stale quality', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const cases = [
      (
        status: VoiceConnectionBadgeStatus.disconnected,
        visible: 'Не подключено',
        announcement: 'Голос не подключён',
      ),
      (
        status: VoiceConnectionBadgeStatus.error,
        visible: 'Ошибка подключения',
        announcement: 'Ошибка голосового подключения',
      ),
    ];

    for (final testCase in cases) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceConnectionBadge(
              status: testCase.status,
              quality: ConnectionQuality.excellent,
              pingMs: 42,
            ),
          ),
        ),
      );

      expect(find.text(testCase.visible), findsOneWidget);
      expect(find.byType(VoiceQualityIndicator), findsNothing);
      expect(find.text('42 мс'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.liveRegion == true &&
              widget.properties.label == testCase.announcement,
        ),
        findsOneWidget,
      );
    }

    semantics.dispose();
  });
}
