import 'dart:io';

import 'package:flutter/services.dart';

import 'local_feed.dart';

import 'artifact.dart';
import 'native_adapter.dart';

class SparkleDesktopUpdater implements DesktopNativeUpdater {
  SparkleDesktopUpdater({MethodChannel? channel})
    : channel = channel ?? const MethodChannel('boohtacord/desktop_updates');
  final MethodChannel channel;
  SelectedPackageFeed? _feed;
  Future<void> closeFeed() async {
    await _feed?.close();
    _feed = null;
  }

  Map<String, dynamic> _args(
    VerifiedInstallArtifact artifact,
    String archive,
    String extracted,
  ) => {
    'artifact': artifact.values,
    'archive': archive,
    'extracted': extracted,
  };
  @override
  Future<bool> capable() async =>
      await channel.invokeMethod<bool>('capable') ?? false;
  @override
  Future<int> freeBytes(String directory) async =>
      await channel.invokeMethod<int>('freeBytes', {'directory': directory}) ??
      0;
  @override
  Future<void> stage(
    VerifiedInstallArtifact artifact,
    String archive,
    String extracted,
  ) => channel.invokeMethod<void>('stage', _args(artifact, archive, extracted));
  @override
  Future<void> apply(
    VerifiedInstallArtifact artifact,
    String archive,
    String extracted,
  ) async {
    await closeFeed();
    final feed = await SelectedPackageFeed.start(
      File(archive),
      build: artifact.nativeBuild,
      version: artifact.version,
      signature: artifact.nativeSignature!,
    );
    _feed = feed;
    try {
      await channel.invokeMethod<void>('apply', {
        ..._args(artifact, archive, extracted),
        'feed_url': feed.feedUrl.toString(),
        'archive_url': feed.archiveUrl.toString(),
      });
    } catch (_) {
      await closeFeed();
      rethrow;
    }
  }

  @override
  Future<void> acknowledge(
    String releaseId,
    String version,
    String nativeBuild,
  ) => channel.invokeMethod<void>('acknowledge', {
    'release_id': releaseId,
    'version': version,
    'native_build': nativeBuild,
  });
}
