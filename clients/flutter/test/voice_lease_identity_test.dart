import 'package:boohtacord_desktop/src/features/voice/screen_viewer_presence/identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extracts only canonical voice lease LiveKit identities', () {
    expect(
      voiceLeaseIdFromLiveKitIdentity(
        'voice-lease:11111111-1111-4111-8111-111111111111',
      ),
      '11111111-1111-4111-8111-111111111111',
    );
    expect(voiceLeaseIdFromLiveKitIdentity('account:11111111'), isNull);
    expect(voiceLeaseIdFromLiveKitIdentity('voice-lease:not-a-uuid'), isNull);
    expect(voiceLeaseIdFromLiveKitIdentity(null), isNull);
  });
}
