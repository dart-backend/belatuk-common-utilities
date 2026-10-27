import 'package:belatuk_merge_map/belatuk_merge_map.dart';
import 'package:test/test.dart';

void main() {
  group('nested maps', () {
    test('merge when their key types differ from the outer map', () {
      var merged = mergeMap<String, dynamic>([
        {
          'a': {1: 'x'},
        },
        {
          'a': {2: 'y'},
        },
      ]);
      expect(merged['a'], {1: 'x', 2: 'y'});
    });

    test('keep the outer types when they fit', () {
      var merged = mergeMap<String, dynamic>([
        {
          'a': <String, dynamic>{
            'b': <String, dynamic>{'c': 1},
          },
        },
        {
          'a': <String, dynamic>{
            'b': <String, dynamic>{'d': 2},
          },
        },
      ]);
      expect(merged['a'], isA<Map<String, dynamic>>());
      expect(merged['a']['b'], isA<Map<String, dynamic>>());
      expect(merged['a']['b'], {'c': 1, 'd': 2});
    });

    test('overwrite when a merged map would not fit the value type', () {
      var merged = mergeMap<String, Map<String, int>>([
        {
          'a': {'x': 1},
        },
        {
          'a': {'y': 2},
        },
      ]);
      expect(merged['a'], {'y': 2});
    });

    test('are not changed by merging', () {
      var first = <String, dynamic>{'x': 1};
      mergeMap<String, dynamic>([
        {'a': first},
        {
          'a': {'y': 2},
        },
      ]);
      expect(first, {'x': 1});
    });

    test('overwrite when not recursive', () {
      var merged = mergeMap<String, dynamic>([
        {
          'a': {'x': 1},
        },
        {
          'a': {'y': 2},
        },
      ], recursive: false);
      expect(merged['a'], {'y': 2});
    });
  });

  group('null values', () {
    test('are skipped by default', () {
      var merged = mergeMap<String, int?>([
        {'a': 1},
        {'a': null, 'b': null},
      ]);
      expect(merged, {'a': 1});
    });

    test('are copied with acceptNull', () {
      var merged = mergeMap<String, int?>([
        {'a': 1},
        {'a': null},
      ], acceptNull: true);
      expect(merged, {'a': null});
    });

    test('are skipped inside nested maps by default', () {
      var merged = mergeMap<String, dynamic>([
        {
          'a': {'x': 1},
        },
        {
          'a': {'x': null},
        },
      ]);
      expect(merged['a'], {'x': 1});
    });
  });
}
