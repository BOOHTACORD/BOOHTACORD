import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

/// Android voice calls need communication routing without stealing focus
/// from other apps. WebRTC.initialize() alone does not set AudioSwitch focus.
final androidVoiceAudioConfiguration = rtc.AndroidAudioConfiguration(
  manageAudioFocus: false,
  androidAudioMode: rtc.AndroidAudioMode.inCommunication,
  androidAudioFocusMode: rtc.AndroidAudioFocusMode.gain,
  androidAudioStreamType: rtc.AndroidAudioStreamType.voiceCall,
  androidAudioAttributesUsageType:
      rtc.AndroidAudioAttributesUsageType.voiceCommunication,
  androidAudioAttributesContentType:
      rtc.AndroidAudioAttributesContentType.speech,
);
