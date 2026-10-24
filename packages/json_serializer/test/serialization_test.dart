//import 'package:dart2_constant/convert.dart';
import 'dart:convert';

import 'package:belatuk_json_serializer/belatuk_json_serializer.dart' as god;
import 'package:logging/logging.dart';
import 'package:test/test.dart';

import 'shared.dart';

void main() {
  god.logger.onRecord.listen(printRecord);

  group('serialization', () {
    test('serialize primitives', testSerializationOfPrimitives);

    test('serialize dates', testSerializationOfDates);

    test('serialize maps', testSerializationOfMaps);

    test('serialize lists', testSerializationOfLists);

    test('serialize via reflection', testSerializationViaReflection);

    test('a getter that throws fails the call', () {
      expect(
        () => god.serialize(ThrowingGetterClass()),
        throwsA(isA<StateError>()),
      );
      // One level down, the error used to be swallowed and the field left out.
      expect(
        () => god.serialize(NestedThrowingGetterClass()),
        throwsA(isA<StateError>()),
      );
    });

    test('private getters are left out', () {
      expect(
        json.decode(god.serialize(PrivateStateClass())),
        equals({'visible': 'yes'}),
      );
    });

    test('a cycle throws instead of overflowing the stack', () {
      var parent = Node('p');
      var child = Node('c')..parent = parent;
      parent.children.add(child);
      expect(() => god.serialize(parent), throwsA(isA<JsonCyclicError>()));

      // The same object twice, without a cycle, is fine.
      var shared = SampleNestedClass('x');
      expect(
        json.decode(god.serialize([shared, shared])),
        equals([
          {'bar': 'x'},
          {'bar': 'x'},
        ]),
      );
    });

    test('non-string map keys become strings', () {
      expect(
        json.decode(god.serialize({1: 'a', DateTime.utc(2026): 'b'})),
        equals({'1': 'a', '2026-01-01T00:00:00.000Z': 'b'}),
      );
    });

    test('values are not logged at INFO', () {
      var records = <LogRecord>[];
      var sub = god.logger.onRecord.listen(records.add);
      god.serialize(SampleNestedClass('secret'));
      god.deserialize('{"bar": "secret"}', outputType: SampleNestedClass);
      sub.cancel();
      expect(records.where((r) => r.message.contains('secret')), isEmpty);
    });

    test(
      'serialize with schema validation',
      testSerializationWithSchemaValidation,
    );
  });
}

void testSerializationOfPrimitives() {
  expect(god.serialize(1), equals("1"));
  expect(god.serialize(1.4), equals("1.4"));
  expect(god.serialize("Hi!"), equals('"Hi!"'));
  expect(god.serialize(true), equals("true"));
  expect(god.serialize(null), equals("null"));
}

void testSerializationOfDates() {
  DateTime date = DateTime.now();
  String s = god.serialize({'date': date});

  print(s);

  var deserialized = json.decode(s);
  expect(deserialized['date'], equals(date.toIso8601String()));
}

void testSerializationOfMaps() {
  var simple = json.decode(
    god.serialize({'hello': 'world', 'one': 1, 'class': SampleClass('world')}),
  );
  var nested = json.decode(
    god.serialize({
      'foo': {
        'bar': 'baz',
        'funny': {'how': 'life', 'seems': 2, 'hate': 'us sometimes'},
      },
    }),
  );

  expect(simple['hello'], equals('world'));
  expect(simple['one'], equals(1));
  expect(simple['class']['hello'], equals('world'));

  expect(nested['foo']['bar'], equals('baz'));
  expect(nested['foo']['funny']['how'], equals('life'));
  expect(nested['foo']['funny']['seems'], equals(2));
  expect(nested['foo']['funny']['hate'], equals('us sometimes'));
}

void testSerializationOfLists() {
  List pandorasBox = [
    1,
    "2",
    {"num": 3, "four": SampleClass('five')},
    SampleClass('six')..nested.add(SampleNestedClass('seven')),
  ];
  String s = god.serialize(pandorasBox);
  print(s);

  var deserialized = json.decode(s);

  expect(deserialized is List, equals(true));
  expect(deserialized.length, equals(4));
  expect(deserialized[0], equals(1));
  expect(deserialized[1], equals("2"));
  expect(deserialized[2] is Map, equals(true));
  expect(deserialized[2]['num'], equals(3));
  expect(deserialized[2]['four'] is Map, equals(true));
  expect(deserialized[2]['four']['hello'], equals('five'));
  expect(deserialized[3] is Map, equals(true));
  expect(deserialized[3]['hello'], equals('six'));
  expect(deserialized[3]['nested'] is List, equals(true));
  expect(deserialized[3]['nested'].length, equals(1));
  expect(deserialized[3]['nested'][0] is Map, equals(true));
  expect(deserialized[3]['nested'][0]['bar'], equals('seven'));
}

void testSerializationViaReflection() {
  SampleClass sample = SampleClass('world');

  for (int i = 0; i < 3; i++) {
    sample.nested.add(SampleNestedClass('baz'));
  }

  String s = god.serialize(sample);
  print(s);

  var deserialized = json.decode(s);
  expect(deserialized['hello'], equals('world'));
  expect(deserialized['nested'] is List, equals(true));
  expect(deserialized['nested'].length == 3, equals(true));
  expect(deserialized['nested'][0]['bar'], equals('baz'));
  expect(deserialized['nested'][1]['bar'], equals('baz'));
  expect(deserialized['nested'][2]['bar'], equals('baz'));
}

void testSerializationWithSchemaValidation() async {
  BabelRc babelRc = BabelRc(
    presets: ['es2015', 'stage-0'],
    plugins: ['add-module-exports'],
  );

  String s = god.serialize(babelRc);
  print(s);

  var deserialized = json.decode(s);

  expect(deserialized['presets'] is List, equals(true));
  expect(deserialized['presets'].length, equals(2));
  expect(deserialized['presets'][0], equals('es2015'));
  expect(deserialized['presets'][1], equals('stage-0'));
  expect(deserialized['plugins'] is List, equals(true));
  expect(deserialized['plugins'].length, equals(1));
  expect(deserialized['plugins'][0], equals('add-module-exports'));

  //Map babelRc2 = {'presets': 'Hello, world!'};

  String json2 = god.serialize(babelRc);
  print(json2);
}
