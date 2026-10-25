part of 'enroll.dart';

extension MobilePairing on MobileEnrollment {
  Future<Map<String, dynamic>> pair(
    Map<String, dynamic> capability,
    Map<String, dynamic> cached,
    Map<String, dynamic> prepared,
    String scope,
    bool Function() active,
    List<int> seed,
    String public,
    PushRegistration registration,
  ) async {
    final device = Map<String, dynamic>.from(prepared['device'] as Map);
    final enrollment = await relay.call('POST', '/v1/devices/challenge', {
      'target': registration.target,
      'target_kind': registration.targetKind,
      'public_key': public,
      'platform': driver.platform,
      'namespace': config.namespace,
    });
    if (!active()) throw const PushUnavailable('cancelled');
    final relayDevice = enrollment['device_id'] as String;
    if (enrollment['state'] == 'pending') {
      final proof = await inbox.take(relayDevice);
      if (!active()) throw const PushUnavailable('cancelled');
      await relay.call(
        'POST',
        '/v1/devices/verify',
        proof,
        seed: seed,
        device: relayDevice,
      );
    } else if (enrollment['state'] != 'active') {
      throw const PushUnavailable('registration_unavailable');
    }
    final receipt = await relay.call(
      'POST',
      '/v1/grants',
      {
        'origin': capability['origin'],
        'installation_id': capability['installation_id'],
        'installation_public_key':
            capability['installation_signing_public_key'],
        'binding_id': device['id'],
        'generation': device['generation'],
        'namespace': config.namespace,
        'nonce': prepared['nonce'],
      },
      seed: seed,
      device: relayDevice,
    );
    if (!active()) throw const PushUnavailable('cancelled');
    final grant = await verifyRelayReceipt(
      receipt,
      publicKey: config.relayPublicKey,
      capability: capability,
      binding: device['id'],
      generation: device['generation'],
      nonce: prepared['nonce'],
      now: DateTime.now().toUtc(),
    );
    if (!active()) throw const PushUnavailable('cancelled');
    cached = {
      ...cached,
      'receipt': receipt,
      'relay_device': relayDevice,
      'grant_id': grant['grant_id'],
      'phase': 'pending_activation',
    };
    await storage.write(scope, cached);
    return _activate(cached, scope, active);
  }
}
