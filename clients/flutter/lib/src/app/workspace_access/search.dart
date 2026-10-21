import '../../models.dart';
import '../../features/workspace/lifecycle/controller.dart';
import '../composition/owners.dart';

mixin AppSearchAccess on AppOwners {
  SearchMessage? get searchContextMessage => workspace.searchContextMessage;

  set searchContextMessage(SearchMessage? value) =>
      workspace.searchContextMessage = value;

  String get searchContextHeading => workspace.searchContextHeading;

  set searchContextHeading(String value) =>
      workspace.searchContextHeading = value;

  List<ChatMessage> get searchContextTextMessages =>
      workspace.searchContextTextMessages;

  set searchContextTextMessages(List<ChatMessage> value) =>
      workspace.searchContextTextMessages = value;

  List<DirectChatMessage> get searchContextDirectMessages =>
      workspace.searchContextDirectMessages;

  set searchContextDirectMessages(List<DirectChatMessage> value) =>
      workspace.searchContextDirectMessages = value;

  bool get loadingSearchContext => workspace.loadingSearchContext;

  set loadingSearchContext(bool value) =>
      workspace.loadingSearchContext = value;

  String? get searchContextError => workspace.searchContextError;

  set searchContextError(String? value) => workspace.searchContextError = value;

  void openSearchPanel({bool currentConversation = false, bool pins = false}) =>
      workspace.openSearchPanel(
        currentConversation: currentConversation,
        pins: pins,
      );

  void closeSearchPanel({bool? restoreLauncherFocus}) =>
      workspace.closeSearchPanel(restoreLauncherFocus: restoreLauncherFocus);

  Future<void> openSearchContext(SearchMessage target, {String? heading}) =>
      workspace.openSearchContext(target, heading: heading);

  Future<void> returnFromSearchContext() => workspace.returnFromSearchContext();
}
