import 'package:flutter/material.dart';

import '../../../theme.dart';

class VoiceScreenAudioControls extends StatelessWidget {
  const VoiceScreenAudioControls({
    super.key,
    required this.showingLocalScreen,
    required this.screenAudioAvailable,
    required this.screenAudioVolume,
    required this.screenAudioMuted,
    required this.onToggleScreenAudio,
    required this.onScreenAudioVolumeChanged,
  });

  final bool showingLocalScreen;
  final bool screenAudioAvailable;
  final int? screenAudioVolume;
  final bool screenAudioMuted;
  final VoidCallback? onToggleScreenAudio;
  final ValueChanged<int>? onScreenAudioVolumeChanged;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 720;

    if (showingLocalScreen) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Предпросмотр собственного экрана без звука.',
            style: TextStyle(color: GcColors.muted, fontSize: 12),
          ),
        ),
      );
    }

    if (!screenAudioAvailable) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'У демонстрации нет аудиодорожки.',
            style: TextStyle(color: GcColors.muted, fontSize: 12),
          ),
        ),
      );
    }

    if (screenAudioVolume == null) {
      return Padding(
        padding: EdgeInsets.fromLTRB(compact ? 8 : 12, 4, compact ? 8 : 12, 4),
        child: Row(
          children: [
            _muteButton(compact: compact),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Аудиодорожка есть; личная настройка громкости недоступна.',
                style: const TextStyle(color: GcColors.muted, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 8 : 12, 4, compact ? 8 : 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            key: const ValueKey('screen-share-audio-toolbar-row'),
            width: double.infinity,
            height: compact ? 48 : 40,
            child: Row(
              children: [
                _muteButton(compact: compact),
                const SizedBox(width: 8),
                if (compact)
                  Expanded(child: _volumeSlider)
                else
                  SizedBox(width: 100, child: _volumeSlider),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  child: Text(
                    '$screenAudioVolume%',
                    key: const ValueKey('screen-share-audio-volume-percent'),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    style: const TextStyle(color: GcColors.muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool get _muted => screenAudioMuted || screenAudioVolume == 0;

  Widget _muteButton({required bool compact}) => Semantics(
    toggled: !_muted,
    child: IconButton(
      tooltip: _muted
          ? 'Включить звук трансляции'
          : 'Выключить звук трансляции',
      constraints: BoxConstraints.tightFor(
        width: compact ? 44 : 32,
        height: compact ? 44 : 32,
      ),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        fixedSize: Size.square(compact ? 44 : 32),
        padding: EdgeInsets.zero,
      ),
      visualDensity: VisualDensity.compact,
      onPressed: onToggleScreenAudio,
      icon: Icon(
        _muted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
        size: compact ? 20 : 18,
      ),
    ),
  );

  Widget get _volumeSlider => Semantics(
    label: 'Громкость звука выбранной демонстрации',
    child: Slider(
      key: const ValueKey('screen-share-audio-volume-slider'),
      value: screenAudioVolume!.toDouble(),
      min: 0,
      max: 200,
      divisions: 200,
      semanticFormatterCallback: (value) => '${value.round()} процентов',
      onChanged: onScreenAudioVolumeChanged == null
          ? null
          : (value) => onScreenAudioVolumeChanged!(value.round()),
    ),
  );
}
