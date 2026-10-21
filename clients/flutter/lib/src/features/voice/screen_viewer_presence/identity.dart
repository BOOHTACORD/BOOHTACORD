import 'validation.dart';

String? voiceLeaseIdFromLiveKitIdentity(String? identity) {
  const prefix = 'voice-lease:';
  if (identity == null || !identity.startsWith(prefix)) return null;
  final leaseId = identity.substring(prefix.length);
  return isScreenViewerUuid(leaseId) ? leaseId.toLowerCase() : null;
}
