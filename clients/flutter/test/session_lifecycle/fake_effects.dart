import 'package:boohtacord_desktop/src/features/session/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/models.dart';

SessionEffects effects({
  Future<void> Function()? clear,
  Future<void> Function()? initialize,
  Future<void> Function(SessionUser)? prepare,
  void Function(String?)? error,
  Future<void> Function()? ready,
  void Function()? invalidate,
  Future<void> Function()? resume,
}) => SessionEffects(
  invalidateOperations: invalidate,
  resume: resume,
  initialize: initialize ?? () async {},
  prepare: prepare ?? (_) async {},
  ready: ready ?? () async {},
  closeMedia: () async {},
  closeRealtime: () async {},
  clearAccount: clear ?? () async {},
  expireAccount: () async {},
  beforeServerChange: () {},
  clearServer: () async {},
  error: error ?? (_) {},
  message: (cause) => cause is ApiFailure ? cause.message : cause.toString(),
);
