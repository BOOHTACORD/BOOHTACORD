import 'package:boohtacord_desktop/src/features/voice/overlay/feed.dart';
import 'package:boohtacord_desktop/src/features/voice/overlay/projection.dart';
import 'package:boohtacord_desktop/src/features/voice/overlay/windows_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('boohtacord/voice_overlay');

  test('sends only bounded display snapshot fields and clears on dispose', () async {
    final calls = <MethodCall>[];
    final messenger = TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final source = ChangeNotifier();
    final feed = VoiceOverlayFeed(
      sources: [source],
      project: (enabled, _) => VoiceOverlaySnapshot(
        visible: enabled,
        members: enabled
            ? const [
                VoiceOverlayMember(
                  displayName: 'Alice',
                  speaking: true,
                  microphoneMuted: false,
                ),
              ]
            : const [],
      ),
    );
    final client = WindowsVoiceOverlayClient(feed: feed, channel: channel);

    await Future<void>.delayed(Duration.zero);
    feed.setEnabled(true);
    await Future<void>.delayed(Duration.zero);
    await client.dispose();

    final visible = calls.firstWhere(
      (call) => (call.arguments as Map)['visible'] == true,
    );
    final arguments = visible.arguments as Map;
    final member = (arguments['members'] as List).single as Map;
    expect(member.keys.toSet(), {
      'displayName',
      'speaking',
      'microphoneMuted',
      'deafened',
    });
    expect(member['deafened'], isFalse);
    expect(member['displayName'], 'Alice');
    expect(calls.last.arguments['visible'], isFalse);
    feed.dispose();
    source.dispose();
  });
}
