class ConversationScrollPosition {
  const ConversationScrollPosition({
    required this.offset,
    required this.followLatest,
    this.anchorId,
    this.anchorOffset = 0,
    this.restoredFromDisk = false,
  });

  final bool restoredFromDisk;
  final String? anchorId;
  final double anchorOffset;
  final double offset;
  final bool followLatest;
}

/// Keeps only local text-history position while the authenticated workspace
/// rebuilds its responsive shell. Message contents are never cached here.
abstract final class ConversationScrollMemory {
  static final Map<String, ConversationScrollPosition> _positions = {};
  static int _epoch = 0;
  static int revision = 0;
  static final Map<String, int> _edits = {};
  static void Function()? changed;
  static List<Map<String, dynamic>> exportForAccount(String account) => [
    for (final entry in _positions.entries)
      if (entry.key.startsWith('$account\u0000'))
        {
          'channel': entry.key.substring(account.length + 1),
          'offset': entry.value.offset,
          'follow_latest': entry.value.followLatest,
          'anchor': entry.value.anchorId,
          'anchor_offset': entry.value.anchorOffset,
        },
  ];
  static void importForAccount(
    String account,
    List<dynamic> values, {
    int? unchangedSince,
  }) {
    _epoch++;
    for (final value in values.take(100)) {
      if (value is! Map ||
          value['channel'] is! String ||
          value['offset'] is! num ||
          !(value['offset'] as num).isFinite ||
          (value['offset'] as num) < 0) {
        continue;
      }
      final key = _key(account, value['channel'] as String);
      if (unchangedSince != null && (_edits[key] ?? 0) > unchangedSince) {
        continue;
      }
      _positions[key] = ConversationScrollPosition(
        offset: (value['offset'] as num).toDouble(),
        followLatest: value['follow_latest'] == true,
        restoredFromDisk: true,
        anchorId: value['anchor'] as String?,
        anchorOffset:
            value['anchor_offset'] is num &&
                (value['anchor_offset'] as num).isFinite
            ? (value['anchor_offset'] as num).toDouble()
            : 0,
      );
    }
  }

  static int get epoch => _epoch;

  static String _key(String accountId, String channelId) =>
      '$accountId\u0000$channelId';

  static ConversationScrollPosition? load(String accountId, String channelId) =>
      _positions[_key(accountId, channelId)];

  static void save({
    required String accountId,
    required String channelId,
    required double offset,
    required bool followLatest,
    required int epoch,
    String? anchorId,
    double anchorOffset = 0,
    bool userInitiated = true,
  }) {
    if (epoch != _epoch || !offset.isFinite || offset < 0) return;
    final key = _key(accountId, channelId);
    if (userInitiated) _edits[key] = ++revision;
    _positions[key] = ConversationScrollPosition(
      offset: offset,
      followLatest: followLatest,
      anchorId: anchorId,
      anchorOffset: anchorOffset,
    );
    changed?.call();
  }

  static void clear() {
    _epoch++;
    _positions.clear();
    _edits.clear();
    revision++;
  }
}
