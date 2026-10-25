import '../mobile_driver/config.dart';
import '../mobile_driver/contracts.dart';
import 'relay_client.dart';
import 'storage.dart';

Future<void> reconcileRevokes(
  BindingStorage storage,
  RelayClient relay,
  PushBuildConfig config,
) async {
  final pending = await storage.pendingRevokes();
  final retained = <Map<String, dynamic>>[];
  var attempts = 0;
  for (final item in pending) {
    final expires = DateTime.tryParse(item['expires_at'] as String? ?? '');
    if (expires != null && !expires.isAfter(DateTime.now().toUtc())) continue;
    if (attempts >= 4 ||
        item['namespace'] != config.namespace ||
        item['origin'] != config.relayOrigin) {
      retained.add(item);
      continue;
    }
    attempts++;
    try {
      final seed = await storage.deviceSeed(config.namespace);
      await relay.call(
        'DELETE',
        '/v1/grants/${item['grant_id']}',
        {},
        seed: seed,
        device: item['device'],
      );
    } catch (_) {
      retained.add(item);
    }
  }
  await storage.saveRevokes(retained);
  if (retained.any(
    (item) =>
        item['namespace'] == config.namespace &&
        item['origin'] == config.relayOrigin,
  )) {
    throw const PushUnavailable('revoke_pending');
  }
}

Future<void> queueGrantRevoke(
  BindingStorage storage,
  PushBuildConfig config,
  Map<String, dynamic>? binding,
) async {
  if (binding == null ||
      binding['grant_id'] is! String ||
      binding['relay_device'] is! String) {
    return;
  }
  final pending = await storage.pendingRevokes();
  pending.removeWhere((item) => item['grant_id'] == binding['grant_id']);
  pending.add({
    'namespace': binding['namespace'] ?? config.namespace,
    'origin': binding['relay_origin'] ?? config.relayOrigin,
    'device': binding['relay_device'],
    'grant_id': binding['grant_id'],
    'expires_at': binding['expires_at'],
  });
  if (pending.length > 32) throw const PushUnavailable('revoke_pending');
  await storage.saveRevokes(pending);
}
