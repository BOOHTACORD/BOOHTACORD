import 'dart:math' as math;
import 'dart:ui';

Rect visibleWindowBounds(Rect saved, List<Rect> displays) {
  if (displays.isEmpty) return saved;
  final title = Rect.fromLTWH(saved.left, saved.top, saved.width, 32);
  final screen =
      displays.where((d) => d.overlaps(title)).firstOrNull ?? displays.first;
  final width = math.min(saved.width, screen.width),
      height = math.min(saved.height, screen.height);
  return Rect.fromLTWH(
    saved.left.clamp(screen.left, screen.right - width),
    saved.top.clamp(screen.top, screen.bottom - height),
    width,
    height,
  );
}
