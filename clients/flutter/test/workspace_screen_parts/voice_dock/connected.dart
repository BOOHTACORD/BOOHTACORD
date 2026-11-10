part of '../../workspace_screen_test.dart';

void _verifyConnectedDock(
  WidgetTester tester,
  _PublishedScreenState state,
  Finder dock,
) {
  final dockDecoration =
      tester.widget<Container>(dock).decoration! as BoxDecoration;
  expect(dockDecoration.color, const Color(0xFF10191A));
  final connectedLabel = find.descendant(
    of: dock,
    matching: find.text('Голос подключён'),
  );
  expect(connectedLabel, findsOneWidget);
  expect(find.text('Подключено'), findsNothing);
  expect(
    find.descendant(of: dock, matching: find.byIcon(Icons.headphones_outlined)),
    findsOneWidget,
  );
  expect(
    tester.widget<Text>(connectedLabel).style?.fontWeight,
    FontWeight.w500,
  );
  expect(find.text('${state.voiceChannel!.name} · 1 участник'), findsOneWidget);
  expect(
    find.descendant(
      of: dock,
      matching: find.byIcon(Icons.signal_cellular_alt_rounded),
    ),
    findsOneWidget,
  );
  expect(find.descendant(of: dock, matching: find.text('42 мс')), findsNothing);
  expect(
    find.descendant(
      of: dock,
      matching: find.bySemanticsLabel(
        'Качество соединения: Нет данных · ping 42 мс',
      ),
    ),
    findsOneWidget,
  );
  expect(
    find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.liveRegion == true &&
          widget.properties.label ==
              'Голос подключён · ${state.voiceChannel!.name}',
    ),
    findsOneWidget,
  );
  final qualitySemantics = tester
      .widgetList<Semantics>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label ==
                  'Качество соединения: Нет данных · ping 42 мс',
        ),
      )
      .toList();
  expect(qualitySemantics, isNotEmpty);
  expect(
    qualitySemantics.every((item) => item.properties.liveRegion != true),
    isTrue,
  );
  expect(find.text('В голосовом канале'), findsWidgets);
}
