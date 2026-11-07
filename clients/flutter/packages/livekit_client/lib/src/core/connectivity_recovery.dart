part of 'engine.dart';

extension _ConnectivityRecovery on Engine {
  void _handleConnectivityChange(SignalConnectivityChangedEvent event) {
    if (_isClosed ||
        !_hasCompletedInitialConnection ||
        _isReconnecting ||
        connectionState != ConnectionState.connected ||
        event.oldState.contains(ConnectivityResult.none) ||
        !event.state.contains(ConnectivityResult.none)) {
      return;
    }

    // A vanished default network can leave the signal socket apparently open.
    // Report recovery immediately and let the existing retry policy own it.
    events.emit(const EngineResumingEvent());
    unawaited(
      handleReconnect(
        ClientDisconnectReason.signal,
        reconnectReason: lk_models.ReconnectReason.RR_SIGNAL_DISCONNECTED,
      ),
    );
  }
}
