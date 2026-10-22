import 'dart:io';

import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin RealtimeConnectFacade on ApiFacadeBase {
  late final _realtimeConnect = RealtimeConnectApi(transport);

  Future<WebSocket> openRealtime({String? after}) =>
      transport.run(() => _realtimeConnect.openRealtime(after: after));
}
