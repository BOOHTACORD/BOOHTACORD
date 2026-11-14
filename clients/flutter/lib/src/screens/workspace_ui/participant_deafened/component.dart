import '../native_bindings.dart';

const workspaceVoiceDeafenedAttribute = 'boohtacord.voice.deafened.v1';

bool workspaceParticipantDeafened(RemoteParticipant participant) =>
    participant.attributes[workspaceVoiceDeafenedAttribute] == 'true';
