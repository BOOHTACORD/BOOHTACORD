import 'dart:io';

import '../../../core/http/facade_base.dart';
import '../maintenance_socket/api.dart';

mixin MaintenanceFacade on ApiFacadeBase {
  late final _publicRealtime = PublicMaintenanceApi(transport);

  Future<WebSocket> openPublicRealtime() => _publicRealtime.open();
  void abortPublicRealtime() => _publicRealtime.abort();
}
