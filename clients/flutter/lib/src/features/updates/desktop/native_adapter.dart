import 'artifact.dart';

abstract interface class DesktopNativeUpdater {
  /// False for ZIP/translocated/read-only installations without a safe updater.
  Future<bool> capable();
  Future<int> freeBytes(String directory);
  Future<void> stage(
    VerifiedInstallArtifact artifact,
    String archive,
    String extracted,
  );

  /// Must be invoked only after checkpoint + graceful shutdown preparation.
  Future<void> apply(
    VerifiedInstallArtifact artifact,
    String archive,
    String extracted,
  );
  Future<void> acknowledge(
    String releaseId,
    String version,
    String nativeBuild,
  );
}
