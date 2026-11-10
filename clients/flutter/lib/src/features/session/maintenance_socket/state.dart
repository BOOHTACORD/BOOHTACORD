import 'package:flutter/foundation.dart';

import '../../realtime/lifecycle/event.dart';
import '../../realtime/lifecycle/maintenance_payload.dart';

class MaintenanceSocketState extends ChangeNotifier {
  bool active = false;
  bool known = false;
  bool _initialized = false, _disposed = false, _owned = false;
  int _owner = 0, _revision = 0;
  String? _generation;

  int begin() {
    if (_disposed) return -1;
    _owner++;
    _owned = true;
    _initialized = false;
    if (known) {
      known = false;
      if (!_disposed) notifyListeners();
    }
    return _owner;
  }

  bool accept(int token, RealtimeEvent event) {
    if (_disposed ||
        !_owned ||
        token != _owner ||
        !isMaintenanceKind(event.kind) ||
        !validMaintenancePayload(event.payload)) {
      return false;
    }
    final generation = event.payload['generation'] as String;
    final revision = (event.payload['revision'] as num).toInt();
    final next = event.payload['active'] as bool;
    if (!_initialized) {
      if (event.kind != 'maintenance.snapshot' ||
          (generation == _generation &&
              (revision < _revision ||
                  (revision == _revision && next != active)))) {
        return false;
      }
    } else if (event.kind != 'maintenance.changed' ||
        generation != _generation ||
        revision <= _revision) {
      return false;
    }
    _generation = generation;
    _revision = revision;
    _initialized = true;
    active = next;
    known = true;
    notifyListeners();
    return true;
  }

  void end(int token) {
    if (_disposed || token != _owner) return;
    _owner++;
    _owned = false;
    _initialized = false;
    if (known) {
      known = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _owner++;
    super.dispose();
  }
}
