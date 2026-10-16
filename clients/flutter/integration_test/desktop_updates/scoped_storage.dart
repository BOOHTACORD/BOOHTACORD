// ignore_for_file: depend_on_referenced_packages
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

/// Real platform storage, scoped exclusively to the disposable acceptance user.
class AcceptanceStorage extends FlutterSecureStoragePlatform {
  AcceptanceStorage(this.delegate, this.namespace) {
    if (!RegExp(r'^ru\.boohtacord\.qa337\.[a-f0-9]{16}$').hasMatch(namespace)) {
      throw ArgumentError('Owned acceptance namespace required');
    }
  }
  final FlutterSecureStoragePlatform delegate;
  final String namespace;
  Map<String, String> options(Map<String, String> original) => {
    ...original,
    'accountName': namespace,
  };
  String scoped(String key) => '$namespace:$key';
  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) => delegate.read(key: scoped(key), options: this.options(options));
  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) => delegate.write(
    key: scoped(key),
    value: value,
    options: this.options(options),
  );
  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) => delegate.delete(key: scoped(key), options: this.options(options));
  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) => delegate.containsKey(key: scoped(key), options: this.options(options));
  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) =>
      throw StateError('Broad storage enumeration forbidden in acceptance');
  @override
  Future<void> deleteAll({required Map<String, String> options}) =>
      throw StateError('Broad storage deletion forbidden in acceptance');
}
