part of '../../app_state_test.dart';

abstract class _FakeApiState extends ApiClient {
  _FakeApiState(
    this.value, {
    this.voiceFailure,
    this.transferFailure,
    this.includeDirectMessage = false,
    this.paginated = false,
  });
  ChannelTopology value;
  final ApiFailure? voiceFailure;
  final ApiFailure? transferFailure;
  final List<bool> voiceTransferAttempts = [];
  final bool includeDirectMessage;
  final bool paginated;
  int olderPageRequests = 0;
  String? advancedMessageId;
  String? advancedTextChannelId;
  String? advancedTextMessageId;
  int textReadAdvances = 0;
  int? editedRevision;
  int? editedDirectRevision;
  int failTextEdits = 0;
  int failDirectEdits = 0;
  int olderTextRevision = 1;
  int? overlappingTextRevision;
  int olderDirectRevision = 1;
  int? overlappingDirectRevision;
  bool reverseEqualTimestampMessageIds = false;
  final Map<String, Completer<void>> textReadCursorGates = {};
  String? deletedTextMessageId;
  String? deletedDirectMessageId;
  String? uploadedTextChannelId;
  String? uploadedDirectMessageId;
  bool passwordResetCompleted = false;
  Object? profileFailure;
  Object? sessionFailure;
  Completer<SessionUser?>? sessionGate;
  Completer<void>? initializationGate;
  String? updatedDisplayName;
  int passwordChangeRequests = 0;
  String? sentReplyToId;
  String? sentDirectReplyToId;
  List<String> sentMentionIds = const [];
  List<String> sentDirectMentionIds = const [];
  List<String> sentAttachmentIds = const [];
  List<String> sentDirectAttachmentIds = const [];
  int failTextSends = 0;
  int failDirectSends = 0;
  Completer<ChatMessagePage>? messagePageGate;
  String? committedTextClientId;
  Completer<void>? textSendGate;
  Completer<void>? textEditGate;
  final textSendIds = <String>[];
  final directSendIds = <String>[];
}

class _FakeApi extends _FakeApiState
    with
        _FakeSearch,
        _FakeIdentity,
        _FakeTopology,
        _FakeDirectSend,
        _FakeDirectHistory,
        _FakeTextHistory,
        _FakeTextWrite,
        _FakeEditsDelete,
        _FakeMedia {
  _FakeApi(
    super.value, {
    super.voiceFailure,
    super.transferFailure,
    super.includeDirectMessage,
    super.paginated,
  });
}
