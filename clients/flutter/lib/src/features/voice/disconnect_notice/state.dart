import 'model.dart';
import 'telemetry.dart';
export 'model.dart';
class VoiceDisconnectState {
  VoiceDisconnectState({void Function(VoiceDisconnectNotice)? report}) : _report = report ?? reportVoiceDisconnect;
  final void Function(VoiceDisconnectNotice) _report;
  VoiceDisconnectNotice? notice;
  String? leaseId, channelId;
  int generation = 0;
  bool _reported = false;
  void _commit() {
    if (notice == null || _reported) return;
    _reported = true;
    try { _report(notice!); } catch (_) {}
  }
  void reset() { _commit(); generation++; leaseId = channelId = null; notice = null; _reported = false; }
  void bind(String lease, String channel) { leaseId = lease; channelId = channel; }
  bool server(String lease, String reason) {
    if (lease.isEmpty || lease != leaseId) return false;
    if (notice?.source != 'server') { notice = VoiceDisconnectNotice(reason, 'server'); _commit(); }
    return true;
  }
  void local() { if (notice?.source != 'server') notice = VoiceDisconnectNotice('VOLUNTARY_LEAVE', 'local'); }
  void transport([String? message]) { notice ??= VoiceDisconnectNotice('TRANSPORT', 'transport', transportMessage: message); }
  void clearTransportForRecovery() { if (notice?.source == 'transport') notice = null; }
  void selectChannel(String id) { if (notice != null && channelId != id) reset(); }
}
