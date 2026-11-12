import 'package:flutter_test/flutter_test.dart';

/// Open the compact drawer again if it closes before its search is usable.
Future<void> ensureNavigationSearchVisible(
  Finder search,
  Future<void> Function() openDrawer,
) async {
  for (var attempt = 0; attempt < 3; attempt++) {
    if (search.hitTestable().evaluate().isNotEmpty) return;
    await openDrawer();
  }
}
