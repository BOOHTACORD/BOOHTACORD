import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import '../integration_test/qa98325_namespace_storage.dart';
class SpyStorage extends FlutterSecureStoragePlatform {
  Map<String,String>? options;
  @override Future<String?> read({required String key,required Map<String,String> options}) async {this.options=options;return null;}
  @override Future<void> delete({required String key,required Map<String,String> options}) async {this.options=options;}
  @override Future<void> write({required String key,required String value,required Map<String,String> options}) async {this.options=options;}
  @override Future<bool> containsKey({required String key,required Map<String,String> options}) async=>false;
  @override Future<Map<String,String>> readAll({required Map<String,String> options}) async=>{};
  @override Future<void> deleteAll({required Map<String,String> options}) async{}
}
void main(){
 test('QA namespace preserves native options and never scans user storage',() async {
  final spy=SpyStorage();final storage=QaNamespaceStorage(spy,'ru.boohtacord.localqa.qa98325.0123456789abcdef',(_,__){});
  await storage.read(key:'boohtacord_session_cookie:https://localhost:5060',options:{'accountName':'production','usesDataProtectionKeychain':'false','synchronizable':'false'});
  expect(spy.options,{'accountName':'ru.boohtacord.localqa.qa98325.0123456789abcdef','usesDataProtectionKeychain':'false','synchronizable':'false'});
  await expectLater(storage.readAll(options:{}),throwsStateError);
  await expectLater(storage.deleteAll(options:{}),throwsStateError);
  expect(()=>QaNamespaceStorage(spy,'production',(_,__){}),throwsArgumentError);
 });
}
