/// Compare the same inbound report across snapshots without exposing IDs.
int packetGrowth(Map<String, int> before, Map<String, int> after) {
  var total = 0;
  for (final entry in after.entries) {
    final old = before[entry.key];
    if (old != null && entry.value > old) total += entry.value - old;
  }
  return total;
}
