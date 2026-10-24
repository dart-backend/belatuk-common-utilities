import 'package:belatuk_json_serializer/belatuk_json_serializer.dart' as god;
import 'package:test/test.dart';

import 'shared.dart';

void main() {
  god.logger.onRecord.listen(printRecord);

  group('deserialization', () {
    test('deserialize primitives', testDeserializationOfPrimitives);

    test('deserialize maps', testDeserializationOfMaps);

    test(
      'deserialize maps + reflection',
      testDeserializationOfMapsWithReflection,
    );

    test(
      'deserialize lists + reflection',
      testDeserializationOfListsAsWellAsViaReflection,
    );

    test(
      'deserialize with schema validation',
      testDeserializationWithSchemaValidation,
    );

    test('extra keys are skipped', () {
      var result = god.deserialize(
        '{"hello": "world", "extra": 1, "readOnly": 2}',
        outputType: SampleClass,
      );
      expect(result, isA<SampleClass>());
      expect((result as SampleClass).hello, equals('world'));
    });

    test('values are converted to their field types', () {
      var result = god.deserialize(
        '{"when": "2026-10-25T10:00:00.000Z", '
        '"created": "2001-02-03T00:00:00.000", "price": 1, '
        '"byName": {"a": {"bar": "x"}}, "items": [{"a": 1}, 2]}',
        outputType: TypedSampleClass,
      ) as TypedSampleClass;
      expect(result.when, equals(DateTime.utc(2026, 10, 25, 10)));
      expect(result.created, equals(DateTime(2001, 2, 3)));
      expect(result.price, equals(1.0));
      expect(result.price, isA<double>());
      expect(result.byName['a'], isA<SampleNestedClass>());
      expect(result.byName['a']!.bar, equals('x'));
      expect(
        result.items,
        equals([
          {'a': 1},
          2,
        ]),
      );
    });

    test('serialize and deserialize round-trip', () {
      var original = TypedSampleClass()
        ..when = DateTime.utc(2026, 10, 25)
        ..price = 2.5
        ..byName = {'b': SampleNestedClass('y')};
      var result = god.deserialize(
        god.serialize(original),
        outputType: TypedSampleClass,
      ) as TypedSampleClass;
      expect(result.when, equals(original.when));
      expect(result.created, equals(original.created));
      expect(result.price, equals(2.5));
      expect(result.byName['b']!.bar, equals('y'));
    });

    test('a class with no no-argument constructor gives a clear error', () {
      expect(
        () => god.deserialize('{"name": "x"}', outputType: RequiredArgClass),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('constructor that takes no arguments'),
          ),
        ),
      );
    });

    test('a field that cannot be set throws', () {
      expect(
        () => god.deserialize('{"hello": 42}', outputType: SampleClass),
        throwsA(anything),
      );
    });
  });
}

void testDeserializationOfPrimitives() {
  expect(god.deserialize('1'), equals(1));
  expect(god.deserialize('1.4'), equals(1.4));
  expect(god.deserialize('"Hi!"'), equals("Hi!"));
  expect(god.deserialize("true"), equals(true));
  expect(god.deserialize("null"), equals(null));
}

void testDeserializationOfMaps() {
  String simpleJson =
      '{"hello":"world", "one": 1, "class": {"hello": "world"}}';
  String nestedJson =
      '{"foo": {"bar": "baz", "funny": {"how": "life", "seems": 2, "hate": "us sometimes"}}}';
  var simple = god.deserialize(simpleJson) as Map;
  var nested = god.deserialize(nestedJson) as Map;

  expect(simple['hello'], equals('world'));
  expect(simple['one'], equals(1));
  expect(simple['class']['hello'], equals('world'));

  expect(nested['foo']['bar'], equals('baz'));
  expect(nested['foo']['funny']['how'], equals('life'));
  expect(nested['foo']['funny']['seems'], equals(2));
  expect(nested['foo']['funny']['hate'], equals('us sometimes'));
}

class Pokedex {
  Map<String, int>? pokemon;
}

void testDeserializationOfMapsWithReflection() {
  var s = '{"pokemon": {"Bulbasaur": 1, "Deoxys": 382}}';
  var pokedex = god.deserialize(s, outputType: Pokedex) as Pokedex;
  expect(pokedex.pokemon, hasLength(2));
  expect(pokedex.pokemon!['Bulbasaur'], 1);
  expect(pokedex.pokemon!['Deoxys'], 382);
}

void testDeserializationOfListsAsWellAsViaReflection() {
  String json = '''[
    {
      "hello": "world",
      "nested": []
    },
    {
      "hello": "dolly",
      "nested": [
        {
          "bar": "baz"
        },
        {
          "bar": "fight"
        }
      ]
    }
  ]
  ''';

  var list = god.deserialize(
    json,
    outputType: (<SampleClass>[]).runtimeType,
  ) as List<SampleClass>;
  SampleClass first = list[0];
  SampleClass second = list[1];

  expect(list.length, equals(2));
  expect(first.hello, equals("world"));
  expect(first.nested.length, equals(0));
  expect(second.hello, equals("dolly"));
  expect(second.nested.length, equals(2));

  SampleNestedClass firstNested = second.nested[0];
  SampleNestedClass secondNested = second.nested[1];

  expect(firstNested.bar, equals("baz"));
  expect(secondNested.bar, equals("fight"));
}

Future<void> testDeserializationWithSchemaValidation() async {
  String babelRcJson =
      '{"presets":["es2015","stage-0"],"plugins":["add-module-exports"]}';

  var deserialized =
      god.deserialize(babelRcJson, outputType: BabelRc) as BabelRc;

  print(deserialized.presets.runtimeType);
  //expect(deserialized.presets is List, equals(true));
  expect(deserialized.presets.length, equals(2));
  expect(deserialized.presets[0], equals('es2015'));
  expect(deserialized.presets[1], equals('stage-0'));
  //expect(deserialized.plugins is List, equals(true));
  expect(deserialized.plugins.length, equals(1));
  expect(deserialized.plugins[0], equals('add-module-exports'));
}
