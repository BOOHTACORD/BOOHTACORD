import 'package:flutter/material.dart';

import '../../../../services/screen_share_quality.dart';
import '../../../../theme.dart';
import 'option.dart';
import 'bandwidth_notice.dart';

class QualityPicker extends StatelessWidget {
  const QualityPicker({
    super.key,
    required this.quality,
    required this.onChanged,
    this.advancedInitiallyExpanded = false,
  });
  final ScreenShareQuality quality;
  final ValueChanged<ScreenShareQuality> onChanged;
  final bool advancedInitiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 24,
        12,
        compact ? 16 : 24,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, size: 17, color: GcColors.textSecondary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Качество трансляции',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 13 : 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              'Выбрано: ${quality.resolution}p · ${quality.frameRate} FPS',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const Text(
            'Фактическое качество зависит от источника, устройства и сети.',
            style: TextStyle(
              color: GcColors.muted,
              fontSize: GcTypography.caption,
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: ExpansionTile(
              key: const ValueKey('screen-share-advanced-quality'),
              initiallyExpanded: advancedInitiallyExpanded,
              maintainState: true,
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text('Дополнительные настройки качества'),
              children: [
                QualityOption(
                  label: 'Разрешение',
                  selectorKey: const ValueKey('resolution-segments'),
                  compact: compact,
                  selected: quality.resolution,
                  values: ScreenShareQuality.resolutions,
                  labelFor: (v) => Text('${v}p', maxLines: 1, softWrap: false),
                  onSelectionChanged: (v) => onChanged(
                    ScreenShareQuality(
                      resolution: v.first,
                      frameRate: quality.frameRate,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                QualityOption(
                  label: 'Частота кадров',
                  selectorKey: const ValueKey('frame-rate-segments'),
                  compact: compact,
                  selected: quality.frameRate,
                  values: ScreenShareQuality.frameRates,
                  labelFor: (v) => Text('$v FPS', maxLines: 1, softWrap: false),
                  onSelectionChanged: (v) => onChanged(
                    ScreenShareQuality(
                      resolution: quality.resolution,
                      frameRate: v.first,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                BandwidthNotice(quality: quality, compact: compact),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
