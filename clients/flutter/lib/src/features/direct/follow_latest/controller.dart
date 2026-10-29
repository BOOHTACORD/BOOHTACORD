import 'package:flutter/widgets.dart';

/// Follows a new tail only when the reader was already at the latest messages.
class DirectHistoryTailFollower {
  String? _scope;
  String? _latest;
  int _generation = 0;

  void observe({
    required String scope,
    required List<String> ids,
    required ScrollController scroll,
    required bool blocked,
    required bool Function() active,
  }) {
    if (_scope != scope) {
      _scope = scope;
      _latest = null;
      _generation++;
    }
    final previous = _latest;
    final latest = ids.lastOrNull;
    _latest = latest;
    if (blocked) {
      _generation++;
      return;
    }
    if (previous == null || latest == previous) return;
    final generation = ++_generation;
    if (latest == null ||
        !ids.contains(previous) ||
        !active() ||
        !scroll.hasClients ||
        scroll.position.isScrollingNotifier.value ||
        scroll.position.extentAfter > 24) {
      return;
    }
    void correct(int remaining, double expectedOffset) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (generation != _generation ||
            !active() ||
            !scroll.hasClients ||
            scroll.position.isScrollingNotifier.value ||
            (scroll.offset - expectedOffset).abs() > 1) {
          return;
        }
        if (scroll.position.extentAfter <= 1) return;
        scroll.jumpTo(scroll.position.maxScrollExtent);
        if (remaining > 1) correct(remaining - 1, scroll.offset);
      });
    }

    correct(8, scroll.offset);
  }
}
