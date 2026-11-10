import '../../../models.dart';
import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin VoiceRosterFacade on ApiFacadeBase {
  late final _voiceRoster = VoiceRosterApi(transport);

  Future<List<VoiceRoomRoster>> voiceParticipants() =>
      transport.run(() => _voiceRoster.voiceParticipants());
}
