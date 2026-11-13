import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Future<void> captureFencedHistory(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
) async {
  await binding.convertFlutterSurfaceToImage();
  await tester.pumpAndSettle();
  await binding.takeScreenshot('android-topology-history-status');
  final close = find.byTooltip('Закрыть навигацию').hitTestable();
  expect(close, findsOneWidget);
  await tester.tap(close);
  await tester.pumpAndSettle();
  expect(find.text('Synthetic history fence'), findsNothing);
  await binding.takeScreenshot('android-topology-history-content');
}
