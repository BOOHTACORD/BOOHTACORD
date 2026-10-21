final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);
final _trackSidPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

bool isScreenViewerUuid(String? value) =>
    value != null && _uuidPattern.hasMatch(value);

bool isScreenViewerTrackSid(String? value) =>
    value != null && _trackSidPattern.hasMatch(value);
