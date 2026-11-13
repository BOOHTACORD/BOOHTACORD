import '../lifecycle/controller.dart';

final _owners = Expando<TopologyRefreshOwner>();

TopologyRefreshOwner topologyRefreshOwner(WorkspaceController workspace) =>
    _owners[workspace] ??= TopologyRefreshOwner();

class TopologyRefreshOwner {
  int _sequence = 0;
  int? _realtime;

  int begin({required bool realtime}) {
    final sequence = ++_sequence;
    _realtime = realtime ? sequence : null;
    return sequence;
  }

  bool current(int sequence) => sequence == _sequence;

  void finish(int sequence) {
    if (_realtime == sequence) _realtime = null;
  }

  void socketEnd() {
    if (_realtime == _sequence) _sequence++;
    _realtime = null;
  }
}
