# Belatuk Merge Map

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/belatuk_merge_map?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![License](https://img.shields.io/github/license/dart-backend/belatuk-common-utilities)](https://github.com/dart-backend/belatuk-common-utilities/blob/main/packages/merge_map/LICENSE)

Combines several maps into one with a single function, `mergeMap`. Later maps override earlier ones, as with [Object.assign](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/assign) in JavaScript, but nested maps are merged too, and `null` values are skipped unless you ask for them. The input maps are never modified.

## Installation

```yaml
dependencies:
  belatuk_merge_map: ^6.0.0
```

## Merging maps

Pass the maps to merge as a list. The result is a new map with the keys of all of them. When a key appears in more than one map, the value from the last one wins, unless both values are maps.

```dart
import 'package:belatuk_merge_map/belatuk_merge_map.dart';

void main() {
  var defaults = {'host': 'localhost', 'port': 8080};
  var overrides = {'port': 3000};

  print(mergeMap([defaults, overrides])); // {host: localhost, port: 3000}
}
```

## Nested maps

By default, when two maps have a map under the same key, the nested maps are merged too, at any depth. Set `recursive: false` to make a later nested map replace an earlier one instead.

```dart
var map1 = <String, dynamic>{'hello': 'world'};
var map2 = <String, dynamic>{
  'foo': {'bar': 'baz', 'this': 'will be overwritten'},
};
var map3 = <String, dynamic>{
  'foo': {'john': 'doe', 'this': 'overrides previous maps'},
};

print(mergeMap([map1, map2, map3]));
// {hello: world, foo: {bar: baz, this: overrides previous maps, john: doe}}

print(mergeMap([map1, map2, map3], recursive: false));
// {hello: world, foo: {john: doe, this: overrides previous maps}}
```

Merged nested maps are new maps, so changing them does not change the input.

## `null` values

By default, a `null` value is skipped, so it does not replace an earlier value. This also applies inside merged nested maps. Set `acceptNull: true` to copy `null` values like any other.

```dart
var maps = <Map<String, int?>>[
  {'a': 1, 'b': 2},
  {'a': null},
];

print(mergeMap(maps)); // {a: 1, b: 2}
print(mergeMap(maps, acceptNull: true)); // {a: null, b: 2}
```

## Types of nested maps

`mergeMap<K, V>` returns a `Map<K, V>`, and the type arguments are usually inferred from the input. Nested maps are typed by these rules:

| Situation | Result |
| --- | --- |
| Every map merged under a key is a `Map<K, V>` | The merged map is a `Map<K, V>`. |
| Some of them are not a `Map<K, V>` | The merged map is a `Map<dynamic, dynamic>`. |
| The merged map is not a valid `V` | The maps are not merged: the later map replaces the earlier one. |

For data such as decoded JSON, use `Map<String, dynamic>`. Nested maps of any type are then merged, and those that are themselves `Map<String, dynamic>` keep that type.

```dart
var merged = mergeMap<String, dynamic>([
  {
    'a': <String, dynamic>{'b': 1},
  },
  {
    'a': {2: 'two'},
  },
]);

print(merged); // {a: {b: 1, 2: two}}
print(merged['a'] is Map<String, dynamic>); // false
```

When `V` is itself a map type, such as `Map<String, int>`, the nested maps are not a `Map<K, V>`, so merging them would give a `Map<dynamic, dynamic>`, which is not a valid `V`. The later map then replaces the earlier one.

```dart
var merged = mergeMap<String, Map<String, int>>([
  {
    'a': {'x': 1},
  },
  {
    'a': {'y': 2},
  },
]);

print(merged); // {a: {y: 2}}
```

## Limitations

A nested map that is not merged with another, and is not a `Map<K, V>`, is put into the result as it is, so the result and the input share it. Changing it in one changes it in the other, and `null` values inside it are kept even without `acceptNull`.

```dart
var settings = {'x': 1};
var merged = mergeMap<String, Map<String, int>>([
  {'a': settings},
]);

print(identical(merged['a'], settings)); // true
```

Copy such maps yourself if you need the result to be independent of the input.

## Upgrading from 5.x

Version 6.0.0 merges nested maps whose key or value types differ from the outer map's, instead of letting them overwrite each other, and keeps the outer types for nested maps more than one level deep when they fit. See the [changelog](CHANGELOG.md) for the full list.
