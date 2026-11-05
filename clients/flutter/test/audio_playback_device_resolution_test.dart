// SoLoud exposes its device constructor as internal; these are test fixtures.
// ignore_for_file: invalid_use_of_internal_member

import 'package:boohtacord_desktop/src/services/audio_device_check.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selects the exact Windows headset instead of virtual speakers', () {
    const virtual = PlaybackDevice(
      2, false, 'Динамики (Jump Desktop Virtual Speaker)',
    );
    const headset = PlaybackDevice(
      3, true, 'Динамики (2- Logitech PRO X Wireless Gaming Headset)',
    );

    expect(
      resolvePlaybackDevice(
        selectedId: 'windows-device-guid',
        selectedLabel: headset.name,
        available: [virtual, headset],
      ),
      same(headset),
    );
  });

  test('rejects ambiguous shortened labels rather than choosing another output', () {
    const virtual = PlaybackDevice(
      2, false, 'Динамики (Jump Desktop Virtual Speaker)',
    );
    const headset = PlaybackDevice(
      3, true, 'Динамики (2- Logitech PRO X Wireless Gaming Headset)',
    );

    expect(
      () => resolvePlaybackDevice(
        selectedId: 'windows-device-guid',
        selectedLabel: 'Динамики (unknown)',
        available: [virtual, headset],
      ),
      throwsA(isA<AudioDeviceCheckFailure>()),
    );
  });

  test('retains a unique normalized fallback and explicit numeric IDs', () {
    const headset = PlaybackDevice(3, true, 'Speakers (Headset)');
    expect(
      resolvePlaybackDevice(
        selectedId: 'windows-device-guid',
        selectedLabel: 'Speakers (alternate label)',
        available: [headset],
      ),
      same(headset),
    );
    expect(
      resolvePlaybackDevice(
        selectedId: '3',
        selectedLabel: 'Different label',
        available: [headset],
      ),
      same(headset),
    );
  });
}
