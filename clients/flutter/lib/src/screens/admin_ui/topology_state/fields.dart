import '../native_bindings.dart';

mixin AdminTopologyFields {
  final adminTitleFocus = FocusNode(debugLabel: 'admin-screen-title');
  final adminCategoryName = TextEditingController();
  final adminCategoryRename = TextEditingController();
  final adminChannelName = TextEditingController();
  final adminChannelRename = TextEditingController();
  final adminChannelDescription = TextEditingController();
  String? adminCategoryId;
  final adminCollapsedTopologyCategories = <String>{};
  String? adminChannelId;
  String? adminMoveChannelId;
  String? adminMoveTargetCategoryId;
  String? adminArchiveChannelId;
  String? adminCloseVoiceChannelId;
  ChannelKind adminChannelKind = ChannelKind.voice;
  late final AdminTopologyMutationController adminTopologyMutations;
  late AdminSection adminSelectedAdminSection;
}
