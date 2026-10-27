# Belatuk JSON Serializer

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/belatuk_json_serializer?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dart-backend/belatuk-common-utilities)](https://github.com/dart-backend/belatuk-common-utilities/blob/main/packages/json_serializer/LICENSE)

A library to convert Dart objects to JSON strings and back, without code generation. It reads and writes an object's fields through reflection with `dart:mirrors`, so it runs on the Dart VM, but not in Flutter, on the web or in compiled executables.

## Installation

```yaml
dependencies:
  belatuk_json_serializer: ^8.0.0
```

## Usage

The library's top-level functions have short, common names such as `serialize`, so import it with a prefix:

```dart
import 'package:belatuk_json_serializer/belatuk_json_serializer.dart'
    as serializer;
```

The examples below use these classes:

```dart
class Address {
  String? city;
}

class User {
  String? name;
  int age = 0;
  DateTime? joined;
  List<String> tags = [];
  Address? address;

  String get greeting => 'Hello, $name';
}
```

## Serializing

`serialize` converts a value to a JSON string. For an object, it writes every public getter, including fields, inherited getters and computed getters such as `greeting`.

```dart
var user = User()
  ..name = 'Ann'
  ..age = 30
  ..joined = DateTime.utc(2026, 1, 2)
  ..tags = ['admin']
  ..address = (Address()..city = 'Oslo');

print(serializer.serialize(user));
// {"name":"Ann","age":30,"joined":"2026-01-02T00:00:00.000Z","tags":["admin"],"address":{"city":"Oslo"},"greeting":"Hello, Ann"}
```

| Value | Written as |
| --- | --- |
| `null`, a `bool`, a `num` or a `String` | Itself |
| A `DateTime` | An ISO 8601 string |
| An `Iterable`, such as a `List` or `Set` | An array |
| A `Map` | An object. Keys that are not strings are converted with `toString`, or to an ISO 8601 string for a `DateTime` |
| An object with a `toJson` method | The result of `toJson`, which is serialized in turn |
| Any other object | An object of its public getters, except `hashCode` and `runtimeType` |

If a getter throws, or its value cannot be serialized, `serialize` throws. An object that contains itself, such as a parent and child that point to each other, throws a `JsonCyclicError`.

`serializeObject` does the same conversion, but returns the maps and lists that would be encoded instead of a string.

## Deserializing

Without an `outputType`, `deserialize` is the same as `json.decode`, and returns maps, lists and primitive values.

```dart
var map = serializer.deserialize('{"hello":"world"}') as Map;
var three = serializer.deserialize('3') as int;
```

### Deserializing into a class

Pass the class as `outputType` to get an instance of it. The result is `dynamic`, so cast it.

```dart
var user = serializer.deserialize(
  '{"name":"Ann","age":30,"joined":"2026-01-02T00:00:00.000Z",'
  '"tags":["admin"],"address":{"city":"Oslo"},"extra":true}',
  outputType: User,
) as User;

print(user.address?.city); // Oslo
print(user.joined?.year); // 2026
```

The class is created with a constructor that can be called with no arguments, and then each JSON key is set on the field or setter with the same name. A key with no matching setter, such as `extra`, or a final field or a getter such as `greeting`, is skipped.

Values are converted to the field's type:

| Field type | Converted from |
| --- | --- |
| A class, such as `Address` | A JSON object, deserialized into that class |
| `List<T>` | An array, with each element converted to `T` |
| `Map<String, T>` | An object, with each value converted to `T` |
| `DateTime` | An ISO 8601 string, as `serialize` writes it |
| `double` | Any number, including a whole number such as `1` |
| `dynamic`, `Object`, or a `List` or `Map` with no type arguments | Nothing. The value is kept as decoded |

If a value cannot be set on its field, for example because it has the wrong type, `deserialize` throws, usually a `TypeError`.

`outputType` can also be a generic type, such as `List<User>` or `Map<String, int>`:

```dart
var users = serializer.deserialize(
  '[{"name":"Ann"},{"name":"Bob"}]',
  outputType: List<User>,
) as List<User>;
```

To convert data that is already decoded, such as a map from a request body, use `deserializeDatum`:

```dart
var user =
    serializer.deserializeDatum({'name': 'Ann'}, outputType: User) as User;
```

### Custom conversion

A class with a `toJson` method is serialized by calling it. A class with a `fromJson` constructor, either generative or factory, is deserialized by calling it with the JSON object, instead of using a constructor with no arguments. This is the way to handle classes with final fields or required constructor arguments.

```dart
class Point {
  final int x;
  final int y;

  Point(this.x, this.y);

  Point.fromJson(Map json) : x = json['x'] as int, y = json['y'] as int;

  Map toJson() => {'x': x, 'y': y};
}
```

```dart
var point =
    serializer.deserialize('{"x":1,"y":2}', outputType: Point) as Point;
print(serializer.serialize(point)); // {"x":1,"y":2}
```

A class that has neither a constructor that can be called with no arguments nor a `fromJson` constructor fails with an `ArgumentError`.

## Logging

The library writes messages to `logger`, a `Logger` from the [logging](https://pub.dev/packages/logging) package, at `Level.FINEST`. They are only built when that level is enabled. They include the values being converted, so enable them only where it is safe to log that data. To listen to them, add `logging` to your dependencies:

```dart
import 'package:logging/logging.dart';

void main() {
  Logger.root.level = Level.ALL;
  serializer.logger.onRecord.listen(print);
}
```

When a conversion fails, the error is also logged at `Level.SEVERE` before it is thrown.

## Limitations

The library uses `dart:mirrors`, which only the Dart VM supports, when it runs code from source as `dart run` does. It cannot be used in Flutter, in web apps, or in executables built with `dart compile exe`.

`deserialize` does not check that the JSON has the shape of `outputType`. For example, deserializing an array with a class as `outputType` returns a `List`, which fails only when you cast it.

Enums are not supported: an enum value is serialized as an object with its `index`, and is not converted back.

The `WithSchema` and `WithSchemaUrl` annotations and the `JsonValidationError` class are exported, but are not used, so no schema validation takes place.

## Upgrading from 7.x

Version 8.0.0 throws instead of skipping a field it cannot convert: `deserialize` throws when a value cannot be set on its field, and `serialize` throws when a getter throws. Private getters are no longer serialized, and log messages are written at `Level.FINEST` instead of `Level.INFO`. See the [changelog](CHANGELOG.md) for the full list.
