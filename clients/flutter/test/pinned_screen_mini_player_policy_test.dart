import 'package:boohtacord_desktop/src/services/pinned_screen_mini_player_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pinned screen mini-player visibility', () {
    bool visible({
      String? pinned = 'participant-1',
      String? activeVoice = 'voice-1',
      String? selected = 'text-1',
      bool directMessageOpen = false,
      bool workspacePanelOpen = false,
    }) => pinnedScreenMiniPlayerVisible(
      pinnedScreenIdentity: pinned,
      activeVoiceChannelId: activeVoice,
      selectedChannelId: selected,
      directMessageOpen: directMessageOpen,
      workspacePanelOpen: workspacePanelOpen,
    );

    test(
      'stays hidden without a pinned remote stream or active voice room',
      () {
        expect(visible(pinned: null), isFalse);
        expect(visible(activeVoice: null), isFalse);
      },
    );

    test('stays in the voice viewer while its channel is visible', () {
      expect(visible(selected: 'voice-1'), isFalse);
    });

    test('appears while a different channel or a DM is open', () {
      expect(visible(selected: 'text-1'), isTrue);
      expect(visible(selected: null, directMessageOpen: true), isTrue);
    });

    test('appears above an open workspace panel', () {
      expect(visible(selected: 'voice-1', workspacePanelOpen: true), isTrue);
    });
  });

  group('voice screen selection channel scope', () {
    test('selection only belongs to the channel where it was made', () {
      expect(
        screenSelectionBelongsToVoiceChannel(
          selectionVoiceChannelId: 'voice-1',
          activeVoiceChannelId: 'voice-1',
        ),
        isTrue,
      );
      expect(
        screenSelectionBelongsToVoiceChannel(
          selectionVoiceChannelId: 'voice-1',
          activeVoiceChannelId: 'voice-2',
        ),
        isFalse,
      );
      expect(
        screenSelectionBelongsToVoiceChannel(
          selectionVoiceChannelId: 'voice-1',
          activeVoiceChannelId: null,
        ),
        isFalse,
      );
    });

    test('local share start returns focus from a remote stream', () {
      expect(
        localScreenShareJustStarted(wasSharing: false, isSharing: true),
        isTrue,
      );
      expect(
        localScreenShareJustStarted(wasSharing: true, isSharing: true),
        isFalse,
      );
      expect(
        localScreenShareJustStarted(wasSharing: false, isSharing: false),
        isFalse,
      );
    });
  });

  group('pinned screen publication lifecycle', () {
    test('distinguishes a missing frame from a removed publication', () {
      expect(
        pinnedScreenPublicationEnded(
          participantPresent: true,
          publicationPresent: true,
        ),
        isFalse,
      );
      expect(
        pinnedScreenPublicationEnded(
          participantPresent: true,
          publicationPresent: false,
        ),
        isTrue,
      );
      expect(
        pinnedScreenPublicationEnded(
          participantPresent: false,
          publicationPresent: false,
        ),
        isTrue,
      );
    });
  });
  group('unpinned remote viewer navigation lifecycle', () {
    bool stop({
      String? selected = 'remote',
      String? waiting,
      String? pinned,
      String? active = 'voice-1',
      String? channel = 'voice-1',
      bool dm = false,
      bool panel = false,
    }) => unpinnedScreenSelectionShouldStop(
      selectedScreenIdentity: selected,
      waitingScreenIdentity: waiting,
      pinnedScreenIdentity: pinned,
      activeVoiceChannelId: active,
      selectedChannelId: channel,
      directMessageOpen: dm,
      workspacePanelOpen: panel,
    );
    test('stops hidden selection on text or another voice channel', () {
      expect(stop(channel: 'text-1'), isTrue);
      expect(stop(channel: 'voice-2'), isTrue);
    });
    test(
      'stops DM and settings even when underlying channel is active voice',
      () {
        expect(stop(dm: true), isTrue);
        expect(stop(panel: true), isTrue);
      },
    );
    test('clears pending restart outside voice before source republish', () {
      expect(stop(selected: '', waiting: 'remote', channel: 'text-1'), isTrue);
      expect(stop(selected: null, waiting: 'remote', dm: true), isTrue);
      expect(stop(selected: '', waiting: 'remote'), isFalse);
    });
    test('preserves pin, visible voice, stopped selection and channel-close ownership', () {
      expect(stop(pinned: 'remote', channel: 'text-1'), isFalse);
      expect(stop(), isFalse);
      expect(stop(selected: '', channel: 'text-1'), isFalse);
      expect(stop(selected: null, channel: 'text-1'), isFalse);
      expect(stop(active: null, channel: 'text-1'), isFalse);
    });
  });
}
