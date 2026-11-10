final _generationId = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

bool isMaintenanceKind(Object? kind) =>
    kind == 'maintenance.snapshot' || kind == 'maintenance.changed';

bool validMaintenancePayload(Object? value) {
  if (value is! Map<String, dynamic> || value.length != 4) return false;
  final version = value['version'], generation = value['generation'];
  final revision = value['revision'], active = value['active'];
  return version is num &&
      version == 1 &&
      generation is String &&
      _generationId.hasMatch(generation) &&
      revision is num &&
      revision.isFinite &&
      revision == revision.truncateToDouble() &&
      revision >= 1 &&
      revision <= 9007199254740991 &&
      active is bool;
}
