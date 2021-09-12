import 'get_value.dart';

/// Parses a URI-encoded string into real data! **Wow!**
///
/// Whichever map you provide will be automatically populated from the urlencoded body string you provide.
void buildMapFromUri(Map map, String body) {
  var parseArrayRgx = RegExp(r'^(.+)\[\]$');

  for (var keyValuePair in body.split('&')) {
    if (keyValuePair.contains('=')) {
      var equals = keyValuePair.indexOf('=');
      var key = Uri.decodeQueryComponent(keyValuePair.substring(0, equals));
      var value = Uri.decodeQueryComponent(keyValuePair.substring(equals + 1));

      if (parseArrayRgx.hasMatch(key)) {
        Match queryMatch = parseArrayRgx.firstMatch(key)!;
        key = queryMatch.group(1)!;
        if (map[key] is! List) {
          map[key] = [];
        }

        map[key].add(getValue(value));
      } else if (key.contains('.')) {
        // i.e. map.foo.bar => [map, foo, bar]
        var keys = key.split('.');

        var targetMap = map[keys[0]] != null ? map[keys[0]] as Map? : {};
        map[keys[0]] = targetMap;
        for (var i = 1; i < keys.length; i++) {
          if (i < keys.length - 1) {
            targetMap![keys[i]] = targetMap[keys[i]] ?? {};
            targetMap = targetMap[keys[i]] as Map?;
          } else {
            targetMap![keys[i]] = getValue(value);
          }
        }
      } else {
        map[key] = getValue(value);
      }
    } else {
      map[Uri.decodeQueryComponent(keyValuePair)] = true;
    }
  }
}
