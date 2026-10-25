import 'package:flutter/foundation.dart';

import 'dart:async';

import 'package:livekit_client/livekit_client.dart';

import '../../services/api_client.dart';
import '../../services/native_notifications.dart';
import '../../features/notifications/remote_lifecycle/controller.dart';
import '../../features/session/lifecycle/controller.dart';
import '../../features/session/reset_state/controller.dart';
import '../../features/session/maintenance_state/controller.dart';
import '../../features/profile/state/controller.dart';
import '../../features/workspace/lifecycle/controller.dart';
import '../../features/conversation/lifecycle/controller.dart';
import '../../features/realtime/lifecycle/controller.dart';
import '../../features/audio/devices/controller.dart';
import '../../features/voice/lifecycle/controller.dart';
import '../../features/voice/overlay/feed.dart';
import '../../features/voice/overlay/windows_client.dart';
import '../../features/voice/overlay/preferences.dart';
import '../../features/voice/roster_state/controller.dart';
import '../../features/screen/lifecycle/controller.dart';
import '../../features/authorization/permissions/controller.dart';
import '../../features/guild/profile/controller.dart';
import '../overlay_preferences/actions.dart';

abstract class AppOwners extends ChangeNotifier {
  AppOwners(
    this.api, {
    this.startupSessionTimeout = const Duration(seconds: 20),
    this.voiceRosterRetryDelay = const Duration(seconds: 2),
    this.voiceRosterStaleTimeout = const Duration(seconds: 10),
    this.audioDeviceLoader,
    this.audioDeviceChanges,
    this.audioDeviceBootstrap,
    this.voiceRoomFactory,
    NativeNotificationService? nativeNotifications,
  }) : nativeNotifications = nativeNotifications ?? NativeNotificationService();
  final ApiClient api;
  final Duration startupSessionTimeout;
  final Duration voiceRosterRetryDelay;
  final Duration voiceRosterStaleTimeout;
  final Future<List<MediaDevice>> Function()? audioDeviceLoader;
  final Stream<List<MediaDevice>>? audioDeviceChanges;
  final Future<void> Function()? audioDeviceBootstrap;
  final Room Function(RoomOptions)? voiceRoomFactory;
  final NativeNotificationService nativeNotifications;
  late final RemoteNotificationController remoteNotifications;
  late final SessionController session;
  late final GuildProfileController guildProfile;
  late final PasswordResetController reset;
  late final MaintenanceController maintenance;
  late final ProfileController profileOwner;
  late final WorkspaceController workspace;
  late final ConversationController conversation;
  late final RealtimeController realtime;
  late final AudioDeviceController audioDevices;
  late final VoiceController voice;
  late final VoiceOverlayFeed voiceOverlay;
  VoiceOverlayPreferences? voiceOverlayPreferences;
  WindowsVoiceOverlayClient? voiceOverlayWindowsClient;
  int voiceOverlaySettingsRevision = 0;
  late final VoiceRosterController voiceRoster;
  late final ScreenShareController screen;
  late final PermissionController permissions;
  String? error;
  bool disposed = false;

  void setVoiceOverlayEnabled(bool enabled) {
    voiceOverlay.setEnabled(enabled);
    final preferences = voiceOverlayPreferences;
    if (preferences != null) {
      unawaited(
        saveOverlayConfiguration(
          preferences.configuration.copyWith(enabled: enabled),
        ).then((accepted) {
          if (!accepted &&
              !disposed &&
              identical(preferences, voiceOverlayPreferences)) {
            error ??= 'Не удалось сохранить или применить настройки overlay.';
            notifyListeners();
          }
        }),
      );
    }
    notifyListeners();
  }

  Future<void> setVoiceOverlayOnlySpeakers(bool value) async {
    final preferences = voiceOverlayPreferences;
    final ticket = session.scope.capture();
    if (preferences == null ||
        !ticket.isActive ||
        session.user?.accountId != preferences.accountId) {
      return;
    }
    if (!await preferences.setOnlySpeakers(value)) {
      if (ticket.isActive) {
        error = 'Не удалось сохранить настройку панели говорящих.';
        notifyListeners();
      }
      return;
    }
    if (!ticket.isActive || session.user?.accountId != preferences.accountId) {
      return;
    }
    voiceOverlay.setOnlySpeakers(value);
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!disposed) super.notifyListeners();
  }
}
