import 'package:flutter/material.dart';

import '../../../theme.dart';
import '../../../widgets/screen_recovery_retry.dart';

class ScreenViewerPendingStatus extends StatelessWidget {
  const ScreenViewerPendingStatus({
    required this.connecting,
    this.recoveryExhausted = false,
    this.onRecoveryRetry,
    super.key,
  });

  final bool connecting;
  final bool recoveryExhausted;
  final VoidCallback? onRecoveryRetry;

  @override
  Widget build(BuildContext context) {
    final retry = connecting && recoveryExhausted && onRecoveryRetry != null;
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Semantics(
            liveRegion: retry,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  retry
                      ? 'Не удалось получить демонстрацию. Повторите просмотр.'
                      : connecting
                      ? 'Подключаемся к демонстрации…'
                      : 'Демонстрация завершена. Выберите другую вручную или вернитесь к участникам.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: GcColors.muted, fontSize: 14),
                ),
                if (retry) ScreenRecoveryRetry(onPressed: onRecoveryRetry!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
