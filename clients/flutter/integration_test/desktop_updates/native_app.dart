// This separate QA entrypoint invokes the shipping application unchanged.
// It is never used by a production build or the normal release scripts.
// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boohtacord_desktop/main.dart' as production;
import 'package:boohtacord_desktop/src/services/api_client.dart';

import 'scoped_storage.dart';

class AcceptanceTls extends HttpOverrides {
  AcceptanceTls(String ca)
    : context = SecurityContext(withTrustedRoots: true)
        ..setTrustedCertificatesBytes(utf8.encode(ca));
  final SecurityContext context;
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context ?? this.context);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final support = await getApplicationSupportDirectory();
  final file = File(
    path.join(support.path, 'issue337-acceptance-private.json'),
  );
  final config = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  final namespace = config['namespace'] as String;
  final storage = AcceptanceStorage(
    FlutterSecureStoragePlatform.instance,
    namespace,
  );
  final origin = Uri.parse(config['origin'] as String);
  if (origin.scheme != 'https' ||
      origin.host != 'localhost' ||
      origin.port != 4910 ||
      origin.path != '/api/v1' ||
      origin.hasQuery ||
      origin.hasFragment ||
      origin.userInfo.isNotEmpty) {
    throw StateError('Only the owned acceptance API is permitted');
  }
  SharedPreferences.setPrefix('flutter.$namespace.');
  FlutterSecureStoragePlatform.instance = storage;
  HttpOverrides.global = AcceptanceTls(config['ca_pem'] as String);
  if (config['bootstrap'] == true) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', origin.toString());
    final api = ApiClient();
    await api.initialize();
    await api.authenticate(
      config['bootstrap_login'] as String,
      config['bootstrap_password'] as String,
      register: false,
    );
    config['bootstrap'] = false;
    config.remove('bootstrap_password');
    await file.writeAsString(jsonEncode(config), flush: true);
  }
  await production.main();
}
