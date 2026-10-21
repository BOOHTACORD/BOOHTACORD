import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension PinnedScreenMiniPlayerHeaderControlsRenderer
    on WorkspacePinnedScreenMiniPlayerContext {
  Widget renderPinnedScreenMiniPlayerHeaderControls(
    BuildContext context,
    String name,
    bool hasAudio,
    RemoteParticipant? participant,
    int? screenVolume, {
    required bool paused,
    required VoidCallback toggleVideo,
    VoidCallback? expand,
    bool singleLine = false,
  }) {
    Widget action(String label, IconData icon, VoidCallback? callback) =>
        IconButton(
          tooltip: label,
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          padding: EdgeInsets.zero,
          onPressed: callback,
          icon: Icon(icon, size: 18),
        );
    final title = Expanded(
      child: Tooltip(
        message: name,
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
    final audio = participant != null && hasAudio;
    final muted =
        audio &&
        (state.deafened ||
            state.screenShareAudioMuted(participant) ||
            screenVolume == 0);
    void sound() {
      if (audio && !state.deafened)
        unawaited(state.toggleScreenShareAudio(participant));
    }

    Future<void> volume() => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Громкость демонстрации'),
        content: AnimatedBuilder(
          animation: state,
          builder: (_, _) => SizedBox(
            width: 240,
            child: IgnorePointer(
              ignoring: state.deafened,
              child: ParticipantVolumeSlider(
                name: name,
                volume: participant == null
                    ? 100
                    : state.screenShareVolume(participant) ?? 100,
                onChanged: (level) {
                  if (participant != null && !state.deafened)
                    unawaited(state.setScreenShareVolume(participant, level));
                },
                onChangeEnd: () {},
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
    final pause = action(
      paused ? 'Продолжить видео' : 'Приостановить видео',
      paused ? Icons.play_arrow : Icons.pause,
      toggleVideo,
    );
    final close = action('Остановить просмотр', Icons.close, onStopWatching);
    if (singleLine)
      return Row(
        children: [
          const SizedBox(width: 8),
          title,
          pause,
          SizedBox.square(
            dimension: 44,
            child: PopupMenuButton<String>(
              tooltip: 'Действия демонстрации',
              onSelected: (value) {
                if (value == 'expand') expand?.call();
                if (value == 'voice') onReturnToVoice();
                if (value == 'sound') sound();
                if (value == 'volume') unawaited(volume());
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'expand',
                  enabled: expand != null,
                  child: const Text('Развернуть демонстрацию'),
                ),
                const PopupMenuItem(value: 'voice', child: Text('К голосу')),
                if (audio)
                  PopupMenuItem(
                    value: 'sound',
                    enabled: !state.deafened,
                    child: Text(muted ? 'Включить звук' : 'Выключить звук'),
                  ),
                if (audio)
                  PopupMenuItem(
                    value: 'volume',
                    enabled: !state.deafened,
                    child: const Text('Громкость демонстрации'),
                  ),
              ],
            ),
          ),
          close,
        ],
      );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.monitor_outlined, size: 17),
            const SizedBox(width: 8),
            title,
            close,
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            pause,
            action('Развернуть демонстрацию', Icons.open_in_full, expand),
            action('К голосу', Icons.graphic_eq_outlined, onReturnToVoice),
            if (audio)
              action(
                muted ? 'Включить звук' : 'Выключить звук',
                muted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
                state.deafened ? null : sound,
              ),
            if (audio)
              action(
                'Громкость демонстрации',
                Icons.tune,
                state.deafened ? null : () => unawaited(volume()),
              ),
          ],
        ),
      ],
    );
  }
}
