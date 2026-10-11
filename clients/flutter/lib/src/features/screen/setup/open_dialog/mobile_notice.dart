import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../../theme.dart';

class MobileCaptureNotice extends StatelessWidget {
  const MobileCaptureNotice({super.key, this.captureScreenAudio = false});
  final bool captureScreenAudio;
  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.symmetric(
      horizontal: MediaQuery.sizeOf(context).width < 640 ? 16 : 28,
    ),
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 640 ? 16 : 24),
    constraints: const BoxConstraints(maxWidth: 520),
    decoration: BoxDecoration(
      color: GcColors.surface,
      border: Border.all(color: GcColors.border),
      borderRadius: BorderRadius.circular(GcRadii.lg),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.privacy_tip_outlined,
          color: GcColors.accentText,
          size: 28,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            defaultTargetPlatform == TargetPlatform.iOS
                ? captureScreenAudio
                      ? 'iOS запустит системную трансляцию ReplayKit. Звук будет передан, если приложение-источник разрешает захват. Остановить трансляцию можно в системной панели или голосовом канале.'
                      : 'Без системной трансляции iOS показывает только содержимое BOOHTACORD. Чтобы запросить звук игры или приложения, включите «Передавать звук экрана».'
                : 'При выборе отдельного приложения Android может скрыть его изображение, когда оно полностью закрыто другим окном или вы переключились на другое приложение. Для непрерывной трансляции выберите весь экран в системном окне Android.',
            style: const TextStyle(color: GcColors.textSecondary, height: 1.45),
          ),
        ),
      ],
    ),
  );
}
