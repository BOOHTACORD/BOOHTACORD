int voiceParticipantColumns({
  required double viewportWidth,
  required double availableWidth,
  required double textScale,
  required int participantCount,
}) {
  final compact = viewportWidth <= 720;
  final scale = textScale.clamp(1.0, 2.0);
  final gap = viewportWidth <= 600 ? 12.0 : 16.0;
  final fitting = compact
      ? ((availableWidth - gap) / 2 < 128 * scale ? 1 : 2)
      : ((availableWidth + 16) / (256 * scale + 16)).floor();
  return fitting.clamp(1, compact ? 2 : 4).clamp(1, participantCount);
}
