# Belatuk JSON Serializer

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/belatuk_json_serializer?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dart-backend/belatuk-common-utilities)](https://github.com/dart-backend/belatuk-common-utilities/blob/main/packages/json_serializer/LICENSE)

**Replacement of `package:json_god` with breaking changes to support NNBD.**

The ***new and improved*** definitive solution for JSON in Dart. It supports synchronously transform an object into a JSON string and also deserialize a JSON string back into an instance of any type.

## Installation

  dependencies:
    belatuk_json_serializer: ^6.0.0

## Usage

It is recommended to import the library under an alias, i.e., `jsonSerializer`.

```dart
import 'package:belatuk_json_serialization/belatuk_json_serialization.dart' as jsonSerializer;
```

## Serializing JSON

Simply call `jsonSerializer.serialize(x)` to synchronously transform an object into a JSON
string.

```dart
Map map = {"foo": "bar", "numbers": [1, 2, {"three": 4}]};

// Output: {"foo":"bar","numbers":[1,2,{"three":4]"}
String json = jsonSerializer.serialize(map);
print(json);
```

You can easily serialize classes, too. Belatuk JSON Serializer also supports classes as members.

```dart

class A {
    String foo;
    A(this.foo);
}

class B {
    late String hello;
    late A nested;
    B(String hello, String foo) {
      this.hello = hello;
      this.nested =  A(foo);
    }
}

main() {
    print(jsonSerializer.serialize( B("world", "bar")));
}

// Output: {"hello":"world","nested":{"foo":"bar"}}
```

If a class has a `toJson` method, it will be called instead.

## Deserializing JSON

Deserialization is equally easy, and is provided through `jsonSerializer.deserialize`.

```dart
Map map = jsonSerializer.deserialize('{"hello":"world"}');
int three = jsonSerializer.deserialize("3");
```

### Deserializing to Classes

Belatuk JSON Serializer lets you deserialize JSON into an instance of any type. Simply pass the type as the second argument to `jsonSerializer.deserialize`.

If the class has a `fromJson` constructor, it will be called instead.

```dart
class Child {
  String foo;
}

class Parent {
  String hello;
  Child child =  Child();
}

main() {
  Parent parent = jsonSerializer.deserialize('{"hello":"world","child":{"foo":"bar"}}', Parent);
  print(parent);
}
```

**Any JSON-deserializable classes must initializable without parameters. If `Foo()` would throw an error, then you can't use Foo with JSON.**

This allows for validation of a sort, as only fields you have declared will be accepted.

```dart
class HasAnInt { int theInt; }

HasAnInt invalid = jsonSerializer.deserialize('["some invalid input"]', HasAnInt);
// Throws an error
```

An exception will be thrown if validation fails.
