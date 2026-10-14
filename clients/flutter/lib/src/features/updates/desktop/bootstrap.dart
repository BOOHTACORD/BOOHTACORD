import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../app_state.dart';
import '../api.dart';
import '../controller.dart';
import '../identity.dart';
import '../restore/checkpoint.dart';
import '../restore/workspace.dart';
import 'artifact.dart';
import 'coordinator.dart';
import 'macos.dart';
import 'staging.dart';
import 'recovery.dart';
import 'velopack.dart';

Future<UpdateController> createNativeUpdateController(AppState state) async {
  final identity = await NativeUpdateIdentity.load();
  final api = UpdateApi(baseUrl: () => state.api.baseUrl);
  if (!Platform.isMacOS && !Platform.isWindows) {
    return UpdateController(api: api, identity: identity);
  }
  final support = await getApplicationSupportDirectory();
  final installation = crypto.sha256
      .convert(utf8.encode(Platform.resolvedExecutable))
      .toString();
  final updateSupport = Platform.isWindows
      ? await getApplicationCacheDirectory()
      : support;
  final root = Directory(
    path.join(updateSupport.path, 'DesktopUpdates', installation),
  );
  final keys = (await rootBundle.loadString('assets/updates/publisher.pub'))
      .trim()
      .split('\n');
  final trust = ArtifactTrust({keys[0].trim(): base64Decode(keys[1].trim())});
  final checkpoint = DesktopCheckpointStore(
    Directory(path.join(support.path, 'DesktopWorkspace')),
  );
  final workspace = DesktopWorkspacePersistence(
    state,
    checkpoint,
    installationNamespace: installation,
  )..start();
  final native = Platform.isMacOS
      ? SparkleDesktopUpdater()
      : VelopackDesktopUpdater(root);
  final store = DesktopUpdateStore(root);
  final recovery = DesktopRecovery(identity.local);
  final desktop = DesktopUpdateCoordinator(
    trust: trust,
    local: identity.local,
    selector: identity.selector,
    environment: identity.environment,
    store: store,
    native: native,
    currentScope: () => workspace.scope,
    checkpoint: workspace.checkpoint,
    shutdown: workspace.gracefulShutdown,
    prepareRecovery: recovery.stage,
    armRecovery: recovery.arm,
    cancelRecovery: recovery.cancel,
  );
  final updates = UpdateController(
    api: api,
    identity: identity,
    desktop: desktop,
    scopeKey: () => workspace.scope,
  );
  desktop.validateBeforeApply = (artifact) async {
    final start = DateTime.now();
    try {
      while (updates.status == UpdateCheckStatus.checking) {
        if (DateTime.now().difference(start) > const Duration(seconds: 10)) {
          return false;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      await updates.check().timeout(const Duration(seconds: 10));
      return updates.status == UpdateCheckStatus.ok &&
          !updates.stale &&
          updates.result == UpdateResult.updateAvailable &&
          updates.policy?.target?.installArtifact?.payload ==
              artifact.envelope.payload;
    } catch (_) {
      return false;
    }
  };
  var scope = workspace.scope;
  state.addListener(() {
    if (scope != workspace.scope) {
      scope = workspace.scope;
      updates.invalidateScope();
    }
  });
  if (native is SparkleDesktopUpdater) {
    native.channel.setMethodCallHandler((call) async {
      if (call.method == 'failed') {
        await native.closeFeed();
        desktop.nativeFailed();
      }
    });
  }
  // The receipt is local and authenticated again; server reachability is not a
  // bootstrap signal. Account-scoped state is consumed only after sign-in.
  final journal = await store.readJournal();
  if (journal?['phase'] == 'applying' &&
      journal?['artifact'] is Map<String, dynamic>) {
    try {
      final envelope = SignedInstallArtifact.fromJson(
        journal!['artifact'] as Map<String, dynamic>,
      );
      final raw = jsonDecode(
        utf8.decode(base64Decode(envelope.payload)),
      ) as Map<String, dynamic>;
      final target = UpdateTarget(
        releaseId: raw['release_id'] as String,
        releaseOrder: raw['release_order'] as int,
        version: raw['version'] as String,
        nativeBuild: raw['native_build'] as String,
        arches: [raw['arch'] as String],
      );
      final transactionDirectory = await store.transaction(target.releaseId);
      final transactionId = journal['transaction'] as String;
      final outcome = await recovery.outcome(
        transactionDirectory,
        transactionId,
      );
      if (outcome?['status'] == 'rolledBack' ||
          outcome?['status'] == 'manualRecovery') {
        await store.writeJournal({...journal, 'phase': outcome!['status']});
        desktop.recovered(rolledBack: outcome['status'] == 'rolledBack');
        return updates;
      }
      final verified = await trust.verify(
        envelope,
        local: identity.local,
        target: target,
        selector: identity.selector,
        environment: identity.environment,
        highestOrder: journal['highest_order'] as int,
        confirmingInstalled: true,
      );
      updates.onLocalBootstrap = () async {
        try {
          await native.acknowledge(
            identity.local.releaseId,
            identity.local.installedVersion!,
            identity.local.nativeBuild!,
          );
          await recovery.acknowledge(
            transactionId,
            verified,
            transactionDirectory,
          );
          await store.writeJournal({...journal, 'phase': 'completed'});
          desktop.confirmCompleted();
          var consumed = false;
          Future<void> consume() async {
            if (consumed ||
                state.phase != AppPhase.ready ||
                workspace.scope != journal['scope']) {
              return;
            }
            consumed = true;
            await checkpoint.consume(
              workspace.scope,
              journal['transaction'] as String,
              identity.local.releaseId,
              identity.local.nativeBuild!,
            );
          }

          state.addListener(() => consume().catchError((Object _) {}));
          await consume();
        } catch (_) {
          desktop.nativeFailed(reason: 'bootstrap_identity');
        }
      };
    } catch (_) {
      desktop.nativeFailed(reason: 'bootstrap_identity');
    }
  }
  return updates;
}
