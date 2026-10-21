import '../../../show_screen_share_setup/component.dart';
import '../../../voice_dock_button/component.dart';
import '../../../voice_dock_ptt_button/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';
import '../../../../voice_overlay_settings/factory.dart';

extension VoiceDockConnectedControlsRenderer on WorkspaceVoiceDockContext {
  Widget renderVoiceDockConnectedControls(BuildContext context) {
    final controls = <Widget>[
      if (compact &&
          state.usesTouchPushToTalk &&
          state.audioActivationMode == AudioActivationMode.ptt)
        WorkspaceVoiceDockPttButton(state: state)
      else
        WorkspaceVoiceDockButton(
          compact: compact,
          tooltip: state.microphoneUnavailable
              ? 'Микрофон недоступен · повторить включение'
              : state.audioActivationMode == AudioActivationMode.ptt
              ? 'Микрофон управляется push-to-talk'
              : state.microphoneMuted
              ? 'Включить микрофон'
              : 'Выключить микрофон',
          semanticsLabel: state.microphoneUnavailable
              ? 'Повторить включение микрофона — микрофон недоступен'
              : state.audioActivationMode == AudioActivationMode.ptt
              ? 'Микрофон управляется push-to-talk'
              : state.microphoneMuted
              ? 'Включить микрофон'
              : 'Выключить микрофон',
          icon: state.microphoneMuted ? Icons.mic_off : Icons.mic,
          danger: state.microphoneMuted,
          dangerActive:
              state.microphoneMuted &&
              !state.microphoneUnavailable &&
              state.audioActivationMode != AudioActivationMode.ptt,
          toggled: !state.microphoneMuted,
          enabled:
              state.audioActivationMode != AudioActivationMode.ptt &&
              !state.deafened,
          onTap: state.toggleMicrophone,
        ),
      WorkspaceVoiceDockButton(
        compact: compact,
        tooltip: state.deafened
            ? 'Включить удалённый звук'
            : 'Выключить удалённый звук',
        icon: state.deafened ? Icons.headset_off : Icons.headphones,
        danger: state.deafened,
        dangerActive: state.deafened,
        toggled: state.deafened,
        enabled:
            !state.deafenChanging && state.voicePhase != VoicePhase.leaving,
        onTap: state.toggleDeafen,
      ),
      WorkspaceVoiceDockButton(
        compact: compact,
        tooltip: switch (state.screenSharePhase) {
          ScreenSharePhase.starting => 'Запускаем демонстрацию экрана…',
          ScreenSharePhase.stopping => 'Останавливаем демонстрацию…',
          ScreenSharePhase.sharing => 'Остановить демонстрацию экрана',
          _ => 'Начать демонстрацию экрана',
        },
        icon: state.screenSharePhase == ScreenSharePhase.sharing
            ? Icons.stop_screen_share_outlined
            : Icons.screen_share_outlined,
        danger: state.screenSharePhase == ScreenSharePhase.sharing,
        enabled: switch (state.screenSharePhase) {
          ScreenSharePhase.starting || ScreenSharePhase.stopping => false,
          ScreenSharePhase.sharing => state.voicePhase != VoicePhase.leaving,
          _ =>
            state.voicePhase == VoicePhase.connected ||
                state.voicePhase == VoicePhase.listener,
        },
        onTap: state.screenSharePhase == ScreenSharePhase.sharing
            ? state.stopScreenShare
            : () => unawaited(workspaceShowScreenShareSetup(context, state)),
      ),
      WorkspaceVoiceDockButton(
        compact: compact,
        tooltip: state.voicePhase == VoicePhase.leaving
            ? 'Выходим…'
            : 'Выйти из голосового канала',
        icon: Icons.call_end,
        danger: true,
        enabled: state.voicePhase != VoicePhase.leaving,
        onTap: state.leaveVoice,
      ),
    ];
    final buttons = <Widget>[
      ...controls.take(3),
      SizedBox.square(
        dimension: compact ? 48 : 40,
        child: PopupMenuButton<String>(
          tooltip: 'Ещё настройки голоса',
          enabled: state.voicePhase != VoicePhase.leaving,
          onSelected: (action) {
            switch (action) {
              case 'sounds':
                unawaited(
                  state.setVoiceStreamSoundEnabled(
                    !state.voiceStreamSoundEnabled,
                  ),
                );
              case 'overlay':
                state.setVoiceOverlayEnabled(!state.voiceOverlay.enabled);
              case 'speakers':
                state.setVoiceOverlayOnlySpeakers(
                  !state.voiceOverlay.onlySpeakers,
                );
              case 'settings':
                unawaited(showVoiceOverlaySettings(context, state));
              case 'edit':
                unawaited(toggleVoiceOverlayEditing(state));
            }
          },
          itemBuilder: (_) => [
            CheckedPopupMenuItem(
              value: 'sounds',
              checked: state.voiceStreamSoundEnabled,
              child: const Text('Сигнал новых трансляций'),
            ),
            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) ...[
              CheckedPopupMenuItem(
                value: 'overlay',
                checked: state.voiceOverlay.enabled,
                enabled: workspaceConnected,
                child: const Text('Панель говорящих'),
              ),
              CheckedPopupMenuItem(
                value: 'speakers',
                checked: state.voiceOverlay.onlySpeakers,
                enabled: workspaceConnected,
                child: const Text('Только говорящие'),
              ),
              PopupMenuItem(
                value: 'settings',
                enabled: workspaceConnected,
                child: const Text('Настройки панели'),
              ),
              PopupMenuItem(
                value: 'edit',
                enabled: workspaceConnected && state.voiceOverlay.enabled,
                child: Text(
                  state.voiceOverlayWindowsClient?.configuration.editing == true
                      ? 'Завершить перемещение'
                      : 'Переместить панель',
                ),
              ),
            ],
          ],
          icon: const Icon(Icons.more_horiz),
        ),
      ),
      controls.last,
    ];
    return LayoutBuilder(
      builder: (_, constraints) {
        final minimumWidth =
            4 * (compact ? 48.0 : 42.0) + (compact ? 48.0 : 40.0);
        if (constraints.maxWidth < minimumWidth) {
          return Wrap(spacing: 4, runSpacing: 4, children: buttons);
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: buttons,
        );
      },
    );
  }
}
