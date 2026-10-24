import 'package:boohtacord_desktop/src/features/workspace/navigation/favorites/preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('preferences are isolated by deployment origin and account', () {
    final first = ChannelFavoritesPreferences(
      accountId: 'account-a',
      baseUrl: 'https://guild.example/api/v1',
    );
    final sameDeploymentOtherAccount = ChannelFavoritesPreferences(
      accountId: 'account-b',
      baseUrl: 'https://guild.example/api/v1',
    );
    final otherDeployment = ChannelFavoritesPreferences(
      accountId: 'account-a',
      baseUrl: 'https://other.example/api/v1',
    );

    expect(first.key, isNot(sameDeploymentOtherAccount.key));
    expect(first.key, isNot(otherDeployment.key));
  });

  test('favorites persist and reject malformed saved identifiers', () async {
    final preferences = ChannelFavoritesPreferences(
      accountId: 'account-a',
      baseUrl: 'https://guild.example/api/v1',
    );

    expect(await preferences.save({'channel-1', 'channel_2'}), isTrue);
    expect(await preferences.read(), {'channel-1', 'channel_2'});

    final storage = await SharedPreferences.getInstance();
    await storage.setString(preferences.key, '["channel-1", 42]');
    expect(await preferences.read(), isEmpty);
  });

  test('preferences with stale session scope cannot write', () async {
    var current = true;
    final preferences = ChannelFavoritesPreferences(
      accountId: 'account-a',
      baseUrl: 'https://guild.example/api/v1',
      current: () => current,
    );
    current = false;

    expect(await preferences.save({'channel-1'}), isFalse);
    expect(await preferences.read(), isEmpty);
  });
}
