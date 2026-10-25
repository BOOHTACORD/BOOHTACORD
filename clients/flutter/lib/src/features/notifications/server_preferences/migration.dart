class NotificationMigrationPreview {
  const NotificationMigrationPreview({
    required this.overrides,
    required this.localDisabled,
  });
  final List<Map<String, dynamic>> overrides;
  final bool localDisabled;
}

// Flutter previously stored only local enabled/sound state. Missing keys and
// local enabled=true never imply remote consent or implicit channel overrides.
NotificationMigrationPreview previewNativeNotificationMigration(
  bool? localEnabled,
) => NotificationMigrationPreview(
  overrides: const [],
  localDisabled: localEnabled == false,
);
