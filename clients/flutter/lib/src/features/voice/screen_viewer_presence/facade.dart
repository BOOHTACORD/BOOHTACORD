import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin ScreenViewerPresenceFacade on ApiFacadeBase {
  late final _screenViewerPresence = ScreenViewerPresenceApi(transport);

  Future<void> setScreenViewerPresence(
    String viewerLeaseId,
    String ownerLeaseId,
    String trackSid,
  ) => transport.run(
    () => _screenViewerPresence.setPresence(
      viewerLeaseId,
      ownerLeaseId,
      trackSid,
    ),
  );

  Future<void> stopScreenViewerPresence(
    String viewerLeaseId,
    String ownerLeaseId,
    String trackSid,
  ) => transport.run(
    () => _screenViewerPresence.stopPresence(
      viewerLeaseId,
      ownerLeaseId,
      trackSid,
    ),
  );

  Future<void> clearScreenViewerAudience(
    String ownerLeaseId, {
    String? trackSid,
  }) => transport.run(
    () => _screenViewerPresence.clearOwnerAudience(
      ownerLeaseId,
      trackSid: trackSid,
    ),
  );

  Future<List<String>> readScreenViewerAccounts(String ownerLeaseId) =>
      transport.run(
        () => _screenViewerPresence.readOwnerAudience(ownerLeaseId),
      );

  Future<List<String>> readScreenViewerAccountsForViewer(
    String viewerLeaseId,
    String ownerLeaseId,
  ) => transport.run(
    () => _screenViewerPresence.readViewerAudience(viewerLeaseId, ownerLeaseId),
  );
}
