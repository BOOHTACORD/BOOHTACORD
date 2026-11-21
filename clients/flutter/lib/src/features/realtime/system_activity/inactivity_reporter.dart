class InactivityReporter {
  Object? _lastSocket;

  void report(Object socket, void Function() send) {
    if (identical(_lastSocket, socket)) return;
    try {
      send();
      _lastSocket = socket;
    } catch (_) {
      // A later confirmed observation may retry on this or a new socket.
    }
  }
}
