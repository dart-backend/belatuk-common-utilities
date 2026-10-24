import 'dart:collection';

import 'get_value.dart';

/// Parses a URI-encoded string into real data! **Wow!**
///
/// Whichever map you provide will be automatically populated from the urlencoded body string you provide.
void buildMapFromUri(Map map, String body) {
  for (var keyValuePair in body.split('&')) {
    // An empty query, a trailing `&` or `&&` leaves an empty pair to skip.
    if (keyValuePair.isEmpty) {
      continue;
    } else if (keyValuePair.contains('=')) {
      var equals = keyValuePair.indexOf('=');
      var key = _decode(keyValuePair.substring(0, equals));
      var value = _decode(keyValuePair.substring(equals + 1));
      setValueFromKey(map, key, value);
    } else {
      _setValue(map, _decode(keyValuePair), true);
    }
  }
}

/// A `%` that does not start an escape, or a run of non-ASCII characters.
final _unescapedRgx = RegExp(r'%(?![0-9A-Fa-f]{2})|[^\x00-\x7F]+');

/// Like [Uri.decodeQueryComponent], but a `%` that does not start an escape
/// and raw non-ASCII characters are kept as is.
///
/// Throws a [FormatException] if the escapes do not decode to valid UTF-8.
String _decode(String component) {
  return Uri.decodeQueryComponent(
    component.replaceAllMapped(
      _unescapedRgx,
      (m) => Uri.encodeComponent(m[0]!),
    ),
  );
}

final _parseArrayRgx = RegExp(r'^(.+)\[\]$');

/// Stores an already-decoded [value] in [map] under [key].
///
/// A key ending in `[]` appends to a list, and a dotted key such as
/// `map.foo.bar` builds nested maps. The two combine, so `map.foo[]` appends
/// to a list inside a nested map.
///
/// Throws a [FormatException] if [key] conflicts with an earlier value, such
/// as `user.name` after `user=bob`, or `tags=x` after `tags[]=y`.
void setValueFromKey(Map map, String key, String value) {
  _setValue(map, key, getValue(value));
}

/// A map built from dotted keys, as opposed to one decoded from JSON.
class _KeyMap extends MapView<dynamic, dynamic> {
  _KeyMap() : super(<dynamic, dynamic>{});
}

/// A list built from `[]` keys, as opposed to one decoded from JSON.
class _KeyList extends ListBase<dynamic> {
  final _list = <dynamic>[];

  @override
  int get length => _list.length;

  @override
  set length(int length) => _list.length = length;

  @override
  dynamic operator [](int index) => _list[index];

  @override
  void operator []=(int index, dynamic value) => _list[index] = value;

  @override
  void add(dynamic element) => _list.add(element);
}

void _setValue(Map map, String key, dynamic value) {
  // i.e. map.foo.bar => [map, foo, bar]
  var keys = key.split('.');
  var targetMap = map;
  for (var i = 0; i < keys.length - 1; i++) {
    // A key holding null still conflicts, so check for the key, not the value.
    var next = targetMap[keys[i]];
    if (!targetMap.containsKey(keys[i])) {
      next = targetMap[keys[i]] = _KeyMap();
    } else if (next is! _KeyMap) {
      throw _conflict(key);
    }
    targetMap = next;
  }

  // Only the last segment can be a list, i.e. map.foo[] => map: {foo: [...]}
  var arrayMatch = _parseArrayRgx.firstMatch(keys.last);
  if (arrayMatch != null) {
    var listKey = arrayMatch[1]!;
    var list = targetMap[listKey];
    if (!targetMap.containsKey(listKey)) {
      list = targetMap[listKey] = _KeyList();
    } else if (list is! _KeyList) {
      throw _conflict(key);
    }
    list.add(value);
  } else {
    // A repeated plain key replaces the earlier value, including a JSON
    // value, but a list or map built from other keys is never replaced.
    var existing = targetMap[keys.last];
    if (existing is _KeyMap || existing is _KeyList) {
      throw _conflict(key);
    }
    targetMap[keys.last] = value;
  }
}

FormatException _conflict(String key) =>
    FormatException('Key "$key" conflicts with an earlier value');
