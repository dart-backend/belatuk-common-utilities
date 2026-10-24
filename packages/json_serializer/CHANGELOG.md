# Change Log

## 8.0.0

### Breaking changes in 8.0.0

* **Breaking:** When a JSON value cannot be set on its field, for example because it has the wrong type, `deserialize` throws instead of logging the error and returning an object with that field left unset. A key with no matching setter, such as an extra field in the JSON or a read-only property, is still skipped.
* **Breaking:** When a getter throws or its value cannot be serialized, at any depth, `serialize` throws instead of leaving that field out of the output.
* **Breaking:** Private getters, such as a `_cache` field, are no longer written to the output.
* **Breaking:** Log messages are written at `Level.FINEST` instead of `Level.INFO`, and are only built when that level is enabled. They include the values being converted, so enable them only where it is safe to log request data.

### Fixes in 8.0.0

* **Deserialize:** A `DateTime` field is read back from the ISO 8601 string that `serialize` writes, and a `double` field accepts a whole number such as `1`, so serializing and deserializing an object gives it back.
* **Deserialize:** The values of a typed map, such as `Map<String, Foo>`, are deserialized to the value type instead of failing the field.
* **Deserialize:** A list with no element type, such as a field declared as `List items`, keeps its elements as they are instead of failing when one is an object.
* **Deserialize:** A class with no constructor that takes no arguments, and no `fromJson` constructor, fails with an error that says so.
* **Serialize:** An object that contains itself, such as a parent and child that point to each other, fails with a `JsonCyclicError` instead of overflowing the stack.
* **Serialize:** Map keys that are not strings, such as `1` or a `DateTime`, are converted to strings instead of making `json.encode` fail.

## 7.5.0

* Require Dart >= 3.13

## 7.4.0

* Require Dart >= 3.8

## 7.3.0

* Require Dart >= 3.5
* Updated `lints` to 5.0.0

## 7.2.0

* Require Dart >= 3.3
* Updated `lints` to 4.0.0

## 7.1.0

* Updated `lints` to 3.0.0
* Fixed lints warnings

## 7.0.0

* Require Dart >= 3.0

## 7.0.0-beta.1

* Require Dart >= 3.0

## 6.0.1

* Updated README

## 6.0.0

* Require Dart >= 2.17

## 5.0.0

* Added `lints` linter
* Removed deprecated parameters
* Published as `belatuk_json_serializer` package

## 4.0.3

* Fixed static analysis errors

## 4.0.2

* Updated pubspec description
* Fixed static analysis errors

## 4.0.1

* Added example
* Updated README

## 4.0.0

* Migrated to support Dart SDK 2.12.x NNBD

## 3.0.0

* Migrated to work with Dart SDK 2.12.x Non NNBD

## 2.0.0-beta+3

* Long-needed updates, ensured Dart 2 compatibility, fixed DDC breakages.
* Patches for reflection bugs with typing.

## 2.0.0-beta+2

* This version breaks in certain Dart versions (likely anything *after* `2.0.0-dev.59.0`)
until <https://github.com/dart-lang/sdk/issues/33594> is resolved.
* Removes the reference to `Schema` class.
