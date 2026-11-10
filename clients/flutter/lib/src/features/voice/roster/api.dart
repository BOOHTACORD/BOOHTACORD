import '../../../models.dart';
import '../../../core/http/api_failure.dart';
import '../../../core/http/transport.dart';

class VoiceRosterApi {
  VoiceRosterApi(this.transport);
  final ApiTransport transport;

  Future<List<VoiceRoomRoster>> voiceParticipants() async {
    final data = await transport.checked(
      await transport.client.get(
        transport.uri('/voice/participants'),
        headers: {...await transport.headers(), 'cache-control': 'no-store'},
      ),
    );
    if (data is! Map<String, dynamic> || data['channels'] is! List) {
      throw const ApiFailure('Некорректный состав голосовых каналов.');
    }
    final rosters = (data['channels'] as List)
        .map((value) => VoiceRoomRoster.fromJson(value as Map<String, dynamic>))
        .toList(growable: false);
    if (rosters.map((item) => item.channelId).toSet().length !=
        rosters.length) {
      throw const ApiFailure('Сервер вернул повторный голосовой канал.');
    }
    return rosters;
  }
}
