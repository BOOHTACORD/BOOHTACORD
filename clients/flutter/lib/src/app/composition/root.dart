import '../conversation_access/attachments.dart';
import '../conversation_access/direct_messages.dart';
import '../conversation_access/text_messages.dart';
import '../media_access/audio_devices.dart';
import '../media_access/screen.dart';
import '../media_access/voice_controls.dart';
import '../media_access/voice_navigation.dart';
import '../media_access/voice_volumes.dart';
import '../media_access/voice_roster.dart';
import '../notification_access/notifications.dart';
import '../notification_access/bind.dart';
import '../profile_access/profile.dart';
import '../session_access/errors.dart';
import '../session_access/maintenance.dart';
import '../session_access/realtime.dart';
import '../session_access/reset.dart';
import '../session_access/session.dart';
import '../workspace_access/direct_navigation.dart';
import '../workspace_access/members.dart';
import '../workspace_access/navigation.dart';
import '../workspace_access/search.dart';
import 'owners.dart';
import 'session.dart';
import 'workspace.dart';
import 'media.dart';
import 'realtime.dart';
import 'dispose.dart';
import 'guild.dart';

class AppState extends AppOwners
    with
        AppAttachmentsAccess,
        AppDirectMessagesAccess,
        AppTextMessagesAccess,
        AppAudioDevicesAccess,
        AppScreenAccess,
        AppVoiceControlsAccess,
        AppVoiceNavigationAccess,
        AppVoiceVolumesAccess,
        AppVoiceRosterAccess,
        AppNotificationsAccess,
        AppProfileAccess,
        AppErrorsAccess,
        AppMaintenanceAccess,
        AppRealtimeAccess,
        AppResetAccess,
        AppSessionAccess,
        AppDirectNavigationAccess,
        AppMembersAccess,
        AppNavigationAccess,
        AppSearchAccess {
  AppState(
    super.api, {
    super.startupSessionTimeout,
    super.voiceRosterRetryDelay,
    super.voiceRosterStaleTimeout,
    super.audioDeviceLoader,
    super.audioDeviceChanges,
    super.audioDeviceBootstrap,
    super.nativeNotifications,
    super.voiceRoomFactory,
  }) {
    configureGuild(this);
    configureSession(this);
    configureWorkspace(this);
    configureMedia(this);
    configureNotifications(this);
    configureRealtime(this);
  }
  @override
  void dispose() {
    disposeOwners(this);
    super.dispose();
  }
}
