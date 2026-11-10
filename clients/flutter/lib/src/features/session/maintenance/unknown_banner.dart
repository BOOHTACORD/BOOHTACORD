import 'package:flutter/material.dart';

import '../../../theme.dart';

class MaintenanceUnknownBanner extends StatelessWidget {
  const MaintenanceUnknownBanner({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      key: const ValueKey('maintenance-unknown-banner'),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 44),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: GcColors.warningBackground,
      child: const Text(
        'Проверяем статус обслуживания и восстанавливаем связь…',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: GcColors.warning,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 20 / 14,
          decoration: TextDecoration.none,
        ),
      ),
    ),
  );
}
