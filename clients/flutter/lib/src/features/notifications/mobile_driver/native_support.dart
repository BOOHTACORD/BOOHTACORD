import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('boohtacord/notifications');
bool get mobilePushPlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);
Future<void> prepareNativePush() async {
  if (!mobilePushPlatform) return;
  if (defaultTargetPlatform == TargetPlatform.android) {
    final state = await _channel.invokeMethod<String>('prepare');
    if (state != 'available') throw PlatformException(code: 'GMS_UNAVAILABLE');
  }
}

Future<void> clearRemoteCards(String? binding) async {
  if (mobilePushPlatform && binding != null) {
    await _channel.invokeMethod<void>('clearRemoteCards', {
      'binding_ref': binding,
    });
  }
}
