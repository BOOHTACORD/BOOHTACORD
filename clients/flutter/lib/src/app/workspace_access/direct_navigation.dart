import '../../models.dart';
import '../../features/workspace/lifecycle/controller.dart';
import '../composition/owners.dart';

mixin AppDirectNavigationAccess on AppOwners {
  bool get supportOpening => workspace.supportOpening;
  bool get supportAvailable => workspace.supportContact.available;
  bool get supportChanged => workspace.supportChanged;
  String? get supportNotice => workspace.supportNotice;
  String? get supportAccountId => workspace.supportContact.accountId;
  bool isSupportConversation(DirectConversation value) =>
      workspace.isSupportConversation(value);
  String directDisplayName(DirectConversation value) =>
      workspace.directDisplayName(value);
  Future<bool> openSupport() => workspace.openSupport();
  List<DirectConversation> get directMessages => workspace.directMessages;

  set directMessages(List<DirectConversation> value) =>
      workspace.directMessages = value;

  List<DirectCandidate> get directMessageCandidates =>
      workspace.directMessageCandidates;

  set directMessageCandidates(List<DirectCandidate> value) =>
      workspace.directMessageCandidates = value;

  DirectConversation? get selectedDirectMessage =>
      workspace.selectedDirectMessage;

  set selectedDirectMessage(DirectConversation? value) =>
      workspace.selectedDirectMessage = value;

  Future<void> refreshDirectMessages() => workspace.refreshDirectMessages();

  Future<void> showDirectMessages() => workspace.showDirectMessages();

  Future<void> openDirectConversation(DirectConversation conversation) =>
      workspace.openDirectConversation(conversation);

  Future<void> createDirectConversation(DirectCandidate candidate) =>
      workspace.createDirectConversation(candidate);
}
