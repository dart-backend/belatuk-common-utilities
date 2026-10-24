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
      // A pair with no key is skipped before its value is decoded, so a bad
      // escape in a value that is thrown away cannot fail the parse.
      if (key.isEmpty) {
        continue;
      }
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
/// to a list inside a nested map. An empty [key] is ignored.
///
/// Throws a [FormatException] if [key] conflicts with an earlier value, such
/// as `user.name` after `user=bob`, or `tags=x` after `tags[]=y`, or if [key]
/// contains a control character. Keys inside a JSON-looking [value] are data,
/// so they are not checked.
void setValueFromKey(Map map, String key, String value) {
  // A value with no key, such as `=v` or a multipart field with `name=""`,
  // has nowhere to go, so it is dropped without being converted.
  if (key.isNotEmpty) {
    _setValue(map, key, getValue(value));
  }
}

/// C0 control characters (including CR, LF and NUL), DEL, C1 control
/// characters (including U+0085 and U+009B), the line breaks U+2028 and
/// U+2029, and the bidi controls that can make text display in a misleading
/// order (U+061C, U+200E, U+200F, U+202A to U+202E, and U+2066 to U+2069).
final _controlCharRgx = RegExp(
  r'[\x00-\x1F\x7F-\x9F\u061C\u200E\u200F\u2028-\u202E\u2066-\u2069]',
);

/// Throws a [FormatException] if [value] contains a control character or
/// line break.
///
/// Form and query keys and multipart field names are often logged or put in
/// headers, where a line break could inject text.
void checkNoControlChars(String value) {
  if (_controlCharRgx.hasMatch(value)) {
    // The value is left out, so logging the error cannot inject text either.
    throw const FormatException(
      'A key or field name contains a control character, line break or bidi '
      'control',
    );
  }
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
  // Checked first, so no later error message can carry a line break.
  checkNoControlChars(key);

  // i.e. map.foo.bar => [map, foo, bar]
  var keys = key.split('.');

  // Every segment needs a name, and only the last can be a list, since lists
  // of maps and lists of lists are not supported.
  RegExpMatch? arrayMatch;
  for (var i = 0; i < keys.length; i++) {
    var list = _parseArrayRgx.firstMatch(keys[i]);
    var name = list?[1] ?? keys[i];
    var isLast = i == keys.length - 1;
    if (name.isEmpty || name.contains('[]') || (list != null && !isLast)) {
      throw FormatException('Key "$key" is not valid');
    }
    if (isLast) {
      arrayMatch = list;
    }
  }

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
