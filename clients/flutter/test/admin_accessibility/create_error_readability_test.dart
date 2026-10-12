import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/features/authorization/permissions/model.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:boohtacord_desktop/src/widgets/topology_actions/create_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 360.0, 393.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('create validation wraps at $width and text scale $scale', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        try {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 640);
          addTearDown(tester.view.reset);
          final state = AppState(ApiClient())
            ..user = const SessionUser(
              accountId: 'qa-account',
              role: 'ADMINISTRATOR',
            )
            ..topology = const ChannelTopology(revision: 1, categories: []);
          state.permissions.snapshot = const PermissionSnapshot(
            accountId: 'qa-account',
            role: GuildRole.administrator,
            revision: 1,
            values: {GuildPermission.categoryCreate: true},
          );
          addTearDown(state.dispose);
          await tester.pumpWidget(
            MaterialApp(
              theme: guildTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showTopologyCreateDialog(context, state),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(FilledButton, 'Создать'));
          await tester.pumpAndSettle();
          const error = 'Введите имя до 80 символов.';
          expect(
            tester.getSemantics(find.byType(EditableText)).hint,
            contains(error),
          );
          final text = find.text(error);
          expect(text, findsOneWidget);
          final liveRegion = !MediaQuery.supportsAnnounceOf(
            tester.element(text),
          );
          final containers = tester.widgetList<Semantics>(
            find.ancestor(of: text, matching: find.byType(Semantics)),
          );
          expect(
            containers.any(
              (widget) =>
                  widget.container &&
                  widget.properties.liveRegion == liveRegion,
            ),
            isTrue,
          );
          final rich = find.descendant(
            of: text,
            matching: find.byType(RichText),
          );
          final paragraph = tester.renderObject<RenderParagraph>(rich);
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(tester.takeException(), isNull);
          await tester.tap(find.widgetWithText(TextButton, 'Отмена'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
        } finally {
          semantics.dispose();
        }
      });
    }
  }
}
