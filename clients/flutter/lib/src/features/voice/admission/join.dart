import 'package:livekit_client/livekit_client.dart';

import '../../../models.dart';
import '../lifecycle/controller.dart';
import 'audio.dart';
import 'connect_options.dart';
import 'prepare.dart';
import 'finalize.dart';
import 'enable.dart';
import 'failure.dart';
import '../../telemetry/action_scope/action.dart';
import 'observe.dart';

extension VoiceAdmissionJoin on VoiceController {
  Future<void> joinVoice(GuildChannel channel, {bool listenerOnly = false}) =>
      observeVoiceAdmission(
        this,
        channel,
        listenerOnly,
        () => admitVoice(channel, listenerOnly: listenerOnly),
      );

  Future<void> admitVoice(
    GuildChannel channel, {
    bool listenerOnly = false,
  }) async {
    final ticket = scope.capture();
    final admitted = operationRevision;
    await closing;
    final setup = prepareVoiceAdmission(channel, ticket, admitted);
    if (setup == null) return;
    final revision = setup.revision;
    final disconnectGeneration = setup.disconnectGeneration;
    Room? candidate;
    EventsListener<RoomEvent>? events;
    String? admittedLease;
    var connected = false;
    try {
      final result = await api.voiceCredential(channel.id, transfer: true);
      admittedLease = result.$1;
      if (!active(ticket, revision) ||
          disconnect.generation != disconnectGeneration) {
        throw CancelledVoiceAdmission();
      }
      api.transport.session.telemetry.bindMediaLease(admittedLease);
      disconnect.bind(admittedLease, channel.id);
      void check() => checkCurrentVoiceAdmission(
        ticket,
        revision,
        admittedLease!,
        disconnectGeneration,
      );
      check();
      leaseId = admittedLease;
      await prepareVoiceAudio(
        ticket,
        revision,
        admittedLease,
        disconnectGeneration,
      );
      candidate = createRoom(voiceRoomOptions());
      pendingRoom = candidate;
      bindVoiceRoomEvents(candidate);
      events = voiceEvents;
      ActionScope.current?.step('connect');
      await candidate.connect(
        result.$2.url,
        result.$2.token,
        connectOptions: voiceConnectOptions(),
      );
      check();
      await refreshVoiceAudioAfterConnect(
        ticket,
        revision,
        admittedLease,
        disconnectGeneration,
      );
      await applyVoiceOutputSelection(candidate);
      check();
      room = candidate;
      voiceChannel = channel;
      await syncRemoteVoiceSubscriptions(candidate);
      await applySavedVoiceVolumes(candidate);
      check();
      if (!listenerOnly) ActionScope.current?.step('microphone');
      await enableVoiceMicrophone(candidate, listenerOnly, ticket, revision);
      check();
      voiceParticipantSoundTracker.seed(
        candidate.remoteParticipants.values.map(
          (participant) => participant.identity,
        ),
      );
      startVoiceConnectionStatsPolling(candidate);
      observeVoiceStreamStarts(candidate);
      connected = true;
      ActionScope.current?.step('ready');
    } catch (cause) {
      if (active(ticket, revision)) {
        await failVoiceAdmission(
          cause,
          admittedLease,
          presentCause: disconnect.generation == disconnectGeneration,
        );
      }
    } finally {
      await finalizeVoiceAdmission(
        candidate: candidate,
        events: events,
        lease: admittedLease,
        connected: connected,
        ticket: ticket,
        revision: revision,
      );
    }
  }
}
