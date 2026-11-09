import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/features/authorization/permissions/model.dart';
import 'package:boohtacord_desktop/src/features/audio/devices/state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/services/native_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' show MediaDevice;
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_scope/fakes.dart';

part 'app_state_parts/session/restore.dart';
part 'app_state_parts/session/bootstrap.dart';
part 'app_state_parts/profile/validation.dart';
part 'app_state_parts/topology/selection.dart';
part 'app_state_parts/voice/screen.dart';
part 'app_state_parts/audio/device_hotplug.dart';
part 'app_state_parts/audio/android_usb.dart';
part 'app_state_parts/audio/android_output.dart';
part 'app_state_parts/audio/device_recovery.dart';
part 'app_state_parts/session/ptt_reset.dart';
part 'app_state_parts/text/read_cursor.dart';
part 'app_state_parts/text/send.dart';
part 'app_state_parts/direct/send.dart';
part 'app_state_parts/text/history_order.dart';
part 'app_state_parts/history/reconcile.dart';
part 'app_state_parts/voice/admission.dart';
part 'app_state_parts/direct/read.dart';
part 'app_state_parts/history/edit.dart';
part 'app_state_parts/history/delete.dart';
part 'app_state_parts/attachments/routing.dart';
part 'app_state_parts/fakes/state.dart';
part 'app_state_parts/fakes/search.dart';
part 'app_state_parts/fakes/identity.dart';
part 'app_state_parts/fakes/topology.dart';
part 'app_state_parts/fakes/direct_send.dart';
part 'app_state_parts/fakes/direct_history.dart';
part 'app_state_parts/fakes/text_history.dart';
part 'app_state_parts/fakes/text_write.dart';
part 'app_state_parts/fakes/edits_delete.dart';
part 'app_state_parts/fakes/media.dart';

const textChannel = GuildChannel(
  id: 'channel-1',
  name: 'общий',
  kind: ChannelKind.text,
  admissionClosed: false,
);
const topology = ChannelTopology(
  revision: 1,
  categories: [
    ChannelCategory(
      id: 'category-1',
      name: 'Текстовые каналы',
      channels: [textChannel],
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  _registerSessionRestore();
  _registerSessionBootstrap();
  _registerProfileValidation();
  _registerTopologySelection();
  _registerVoiceScreen();
  _registerAudioHotplug();
  _registerAudioAndroidUsb();
  _registerAudioAndroidOutput();
  _registerAudioRecovery();
  _registerSessionPttReset();
  _registerTextReadCursor();
  _registerTextSend();
  _registerDirectSend();
  _registerTextHistoryOrder();
  _registerHistoryReconcile();
  _registerVoiceAdmission();
  _registerDirectRead();
  _registerHistoryEdit();
  _registerHistoryDelete();
  _registerAttachmentRouting();
}
