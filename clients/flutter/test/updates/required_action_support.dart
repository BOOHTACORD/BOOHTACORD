import 'package:boohtacord_desktop/src/features/updates/api.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';

class FakeLauncher extends UrlLauncherPlatform {
  String? opened;
  bool succeeds = true;
  @override
  LinkDelegate? get linkDelegate => null;
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    opened = url;
    return succeeds;
  }
}

class FakeUpdateApi extends UpdateApi {
  FakeUpdateApi(this.value)
    : super(baseUrl: () => 'https://example.test/api/v1');
  final UpdatePolicy value;
  @override
  Future<UpdatePolicy> fetch(UpdateSelector selector) async => value;
}
