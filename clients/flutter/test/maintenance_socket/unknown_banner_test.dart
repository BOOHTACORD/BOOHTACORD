import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

void main() {
  testWidgets(
    'unknown maintenance is announced until a confirmed state arrives',
    (tester) async {
      final state = AppState(ApiClient())..phase = AppPhase.signedOut;
      addTearDown(state.dispose);
      await tester.pumpWidget(BoohtacordApp(state: state));
      expect(
        find.textContaining('Проверяем статус обслуживания'),
        findsOneWidget,
      );
      expect(find.textContaining('Идёт обновление:'), findsNothing);
      state.maintenanceActive = false;
      await tester.pump();
      expect(
        find.textContaining('Проверяем статус обслуживания'),
        findsNothing,
      );
      state.maintenanceActive = true;
      await tester.pump();
      expect(find.textContaining('Идёт обновление:'), findsOneWidget);
    },
  );
}
