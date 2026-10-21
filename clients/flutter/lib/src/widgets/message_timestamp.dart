import 'package:flutter/material.dart';

import '../theme.dart';

class MessageTimestamp extends StatelessWidget {
  const MessageTimestamp(this.value, {super.key, this.compact = false});
  final DateTime value;
  final bool compact;
  static String short(DateTime value) {
    final d = value.toLocal();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static String full(DateTime value) {
    final d = value.toLocal(), offset = value.toLocal().timeZoneOffset;
    final hours = offset.inMinutes.abs() ~/ 60,
        minutes = offset.inMinutes.abs() % 60;
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} '
        '${short(d)}:${d.second.toString().padLeft(2, '0')} '
        '${d.timeZoneName} (UTC${offset.isNegative ? '-' : '+'}${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')})';
  }

  @override
  Widget build(BuildContext context) => Tooltip(
    message: full(value),
    excludeFromSemantics: true,
    child: Semantics(
      label: full(value),
      child: ExcludeSemantics(
        child: Text(
          short(value),
          maxLines: 1,
          style: TextStyle(color: GcColors.muted, fontSize: compact ? 10 : 12),
        ),
      ),
    ),
  );
}
