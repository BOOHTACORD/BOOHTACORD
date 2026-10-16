// The real SDK can report its original connection failure before lease cleanup
// replaces the UI notice. Retain categories only, never SDK messages/URLs/SDP.
class AcceptanceVoiceDiagnostics {
  final _codes = <String>{};
  List<String> get codes => List.unmodifiable(_codes);

  void observe(String logger, String message) {
    if (logger != 'livekit') return;
    final text = message.toLowerCase();
    final String? code;
    if (text.contains('[mediaconnectexception]')) {
      code = 'ice_connect';
    } else if (text.contains('[negotiationerror]')) {
      code = 'negotiation';
    } else if (text.contains('[certificatepinningexception]') ||
        text.contains('handshakeexception')) {
      code = 'tls';
    } else if (text.contains('no internet connection')) {
      code = 'offline';
    } else if (text.contains('signaljoinresponseevent')) {
      code = 'signaling_timeout';
    } else if (text.contains('received websocket error')) {
      code = 'signaling_socket';
    } else if (text.contains('could not connect to')) {
      code = 'unclassified';
    } else {
      code = null;
    }
    if (code != null) _codes.add(code);
  }
}
