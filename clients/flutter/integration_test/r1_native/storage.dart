import 'dart:collection';
import 'dart:async';

const _actor = #r1CookieActor;

class R1Cookies extends MapBase<String, String> {
  final _stores = <Object, Map<String, String>>{};
  Map<String, String> get data =>
      _stores.putIfAbsent(Zone.current[_actor] ?? #observer, () => {});
  @override
  String? operator [](Object? key) => data[key];
  @override
  void operator []=(String key, String value) => data[key] = value;
  @override
  Iterable<String> get keys => data.keys;
  @override
  void clear() => data.clear();
  @override
  String? remove(Object? key) => data.remove(key);
}

Future<T> peerCookies<T>(Future<T> Function() action) =>
    runZoned(action, zoneValues: {_actor: #peer});
