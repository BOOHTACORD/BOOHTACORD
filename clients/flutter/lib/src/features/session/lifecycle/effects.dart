import 'dart:async';

import '../../../models.dart';

// Composition hooks affect their own feature state; this owner controls ordering.
class SessionEffects {
  const SessionEffects({
    this.invalidateOperations,
    this.resume,
    required this.initialize,
    required this.prepare,
    required this.ready,
    required this.closeMedia,
    required this.closeRealtime,
    required this.clearAccount,
    required this.expireAccount,
    required this.beforeServerChange,
    required this.clearServer,
    required this.error,
    required this.message,
  });
  final Future<void> Function() initialize;
  final Future<void> Function(SessionUser) prepare;
  final Future<void> Function() ready;
  final Future<void> Function() closeMedia;
  final Future<void> Function() closeRealtime;
  final Future<void> Function() clearAccount;
  final Future<void> Function() expireAccount;
  final FutureOr<void> Function() beforeServerChange;
  final Future<void> Function() clearServer;
  final void Function(String?) error;
  final String Function(Object) message;
  final void Function()? invalidateOperations;
  final Future<void> Function()? resume;
}
