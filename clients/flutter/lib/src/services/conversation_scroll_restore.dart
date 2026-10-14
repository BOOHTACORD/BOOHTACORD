import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';

import 'conversation_scroll_memory.dart';

({String id, double offset})? captureConversationAnchor(
  Map<String, GlobalKey> keys,
  String prefix,
) {
  ({String id, double offset})? selected;
  for (final entry in keys.entries) {
    if (!entry.key.startsWith('$prefix:')) continue;
    final row = entry.value.currentContext?.findRenderObject();
    if (row is! RenderBox || !row.attached) continue;
    final viewport = RenderAbstractViewport.maybeOf(row);
    if (viewport is! RenderBox) continue;
    final frame = row.localToGlobal(Offset.zero) & row.size;
    final box = viewport as RenderBox;
    final visible = box.localToGlobal(Offset.zero) & box.size;
    if (!frame.overlaps(visible)) continue;
    final offset = frame.top - visible.top;
    if (selected == null || offset < selected.offset) {
      selected = (id: entry.key.substring(prefix.length + 1), offset: offset);
    }
  }
  return selected;
}

/// Finds a persisted message in a lazy list, then restores its viewport offset.
/// A missing/deleted anchor falls back to the bounded saved pixel position.
Future<void> restoreConversationScroll({
  required ScrollController scroll,
  required ConversationScrollPosition saved,
  required Map<String, GlobalKey> keys,
  required String prefix,
  required List<String> ids,
  required bool Function() active,
}) async {
  double low = 0, high = double.infinity;
  final index = saved.restoredFromDisk ? ids.indexOf(saved.anchorId ?? '') : -1;
  for (var attempt = 0; attempt < 14; attempt++) {
    await WidgetsBinding.instance.endOfFrame;
    if (!active() || !scroll.hasClients) return;
    final position = scroll.position;
    double target;
    if (saved.followLatest) {
      target = position.maxScrollExtent;
    } else {
      final row = saved.restoredFromDisk
          ? keys['$prefix:${saved.anchorId}']?.currentContext
                ?.findRenderObject()
          : null;
      final viewport = row == null ? null : RenderAbstractViewport.maybeOf(row);
      if (row is RenderBox && row.attached && viewport != null) {
        target = viewport.getOffsetToReveal(row, 0).offset - saved.anchorOffset;
      } else if (index >= 0 && attempt > 0) {
        final visible =
            keys.entries
                .where(
                  (e) =>
                      e.key.startsWith('$prefix:') &&
                      e.value.currentContext != null,
                )
                .map((e) => ids.indexOf(e.key.substring(prefix.length + 1)))
                .where((n) => n >= 0)
                .toList()
              ..sort();
        if (visible.isNotEmpty) {
          if (index < visible.first) {
            high = position.pixels;
          } else if (index > visible.last)
            low = position.pixels;
        }
        high = high.clamp(low, position.maxScrollExtent);
        target = high.isFinite
            ? (low + high) / 2
            : position.maxScrollExtent *
                  index /
                  (ids.length - 1).clamp(1, ids.length);
      } else {
        target = saved.offset;
      }
    }
    target = target.clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((position.pixels - target).abs() < .5 &&
        (index < 0 ||
            keys['$prefix:${saved.anchorId}']?.currentContext != null ||
            saved.followLatest)) {
      return;
    }
    position.jumpTo(target);
    WidgetsBinding.instance.scheduleFrame();
  }
}
