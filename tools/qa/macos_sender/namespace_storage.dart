import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

/// Delegate to the installed native Keychain plugin; alter only service scope.
/// Do not enumerate broad Keychain contents or replace persistence with memory.
class QaNamespaceStorage extends FlutterSecureStoragePlatform {
  QaNamespaceStorage(this.delegate,this.namespace,this.observed){
    if(!RegExp(r'^ru\.boohtacord\.localqa\.qa98325\.[a-f0-9]{16}$').hasMatch(namespace)) throw ArgumentError('Owned QA namespace required');
  }
  final FlutterSecureStoragePlatform delegate;
  final String namespace;
  final void Function(String,double) observed;
  Map<String,String> scoped(Map<String,String> options)=>{...options,'accountName':namespace};
  Future<T> timed<T>(String kind,Future<T> Function() action) async {
    final timer=Stopwatch()..start();
    try{return await action();}finally{observed(kind,timer.elapsedMicroseconds/1000);}
  }
  @override Future<String?> read({required String key,required Map<String,String> options})=>timed('read',()=>delegate.read(key:key,options:scoped(options)));
  @override Future<void> write({required String key,required String value,required Map<String,String> options})=>timed('write',()=>delegate.write(key:key,value:value,options:scoped(options)));
  @override Future<void> delete({required String key,required Map<String,String> options})=>timed('delete',()=>delegate.delete(key:key,options:scoped(options)));
  @override Future<bool> containsKey({required String key,required Map<String,String> options})=>timed('contains',()=>delegate.containsKey(key:key,options:scoped(options)));
  @override Future<Map<String,String>> readAll({required Map<String,String> options}) async=>throw StateError('Broad Keychain enumeration forbidden in QA');
  @override Future<void> deleteAll({required Map<String,String> options}) async=>throw StateError('Broad Keychain deletion forbidden in QA');
}
