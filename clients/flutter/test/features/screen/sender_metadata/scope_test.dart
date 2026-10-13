import 'dart:convert';

import 'package:boohtacord_desktop/src/features/screen/sender_metadata/descriptor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  test('keeps old participants compatible when descriptor is absent', () {
    expect(parseScreenShareDescriptor(null), isNull);
    expect(parseScreenShareDescriptor(''), isNull);
    expect(parseScreenShareDescriptor('{broken'), isNull);
  });

  test('rejects unsupported versions, fields and malformed profiles', () {
    expect(parse(descriptor()..['schema_version'] = 99), isNull);
    expect(parse(descriptor()..['mode'] = 'cinema'), isNull);
    expect(parse(descriptor()..['requested_profile_id'] = 'P999_60'), isNull);
    expect(parse(descriptor()..['requested_profile_id'] = 'P1080_45'), isNull);
    expect(parse(descriptor()..['unexpected'] = true), isNull);
    final missingRoom = descriptor();
    (missingRoom['scope'] as Map<String, Object?>).remove('room_id');
    expect(parse(missingRoom), isNull);
    final emptyLayers = descriptor();
    ((emptyLayers['effective_profile'] as Map<String, Object?>)['encoding']
            as Map<String, Object?>)['layers'] = <Map<String, Object?>>[];
    expect(parse(emptyLayers), isNull);
  });

  test('matches sender and room scope and bounds numeric fields', () {
    final raw = jsonEncode(descriptor());
    expect(
      parseScreenShareDescriptor(raw, expectedOriginId: 'https://elsewhere.test'),
      isNull,
    );
    expect(
      parseScreenShareDescriptor(raw, expectedOriginId: 'https://voice.example.test'),
      isNotNull,
    );
    expect(parseScreenShareDescriptor(raw, expectedAccountId: 'account-b'), isNull);
    expect(parseScreenShareDescriptor(raw, expectedRoomId: 'room-b'), isNull);
    final negative = descriptor();
    (negative['scope'] as Map<String, Object?>)['publication_generation'] = -1;
    expect(parse(negative), isNull);
    final unsafe = descriptor();
    (unsafe['scope'] as Map<String, Object?>)['operation_revision'] =
        9007199254740992;
    expect(parse(unsafe), isNull);
    expect(parseScreenShareDescriptor(List.filled(4097, ' ').join()), isNull);
  });
}
