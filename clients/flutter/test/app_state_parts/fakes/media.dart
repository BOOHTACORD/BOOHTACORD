part of '../../app_state_test.dart';

mixin _FakeMedia on _FakeApiState {
  @override
  Future<MessageAttachment> uploadChannelAttachment(
    String channelId,
    String fileName,
    Uint8List bytes, {
    void Function(int sent, int total)? onProgress,
  }) async {
    uploadedTextChannelId = channelId;
    return MessageAttachment(
      id: 'text-file',
      originalName: fileName,
      sizeBytes: bytes.length,
    );
  }

  @override
  Future<MessageAttachment> uploadDirectMessageAttachment(
    String directMessageId,
    String fileName,
    Uint8List bytes, {
    void Function(int sent, int total)? onProgress,
  }) async {
    uploadedDirectMessageId = directMessageId;
    return MessageAttachment(
      id: 'dm-file',
      originalName: fileName,
      sizeBytes: bytes.length,
    );
  }

  @override
  Future<(String, VoiceCredential)> voiceCredential(
    String channelId, {
    bool transfer = false,
  }) async {
    voiceTransferAttempts.add(transfer);
    if (transfer) {
      if (transferFailure case final failure?) throw failure;
    } else if (voiceFailure case final failure?) {
      throw failure;
    }
    return (
      'lease-1',
      const VoiceCredential(url: 'wss://voice.example.test', token: 'token'),
    );
  }
}
