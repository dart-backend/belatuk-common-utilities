/// Exposes the [mergeMap] function, which... merges Maps.
library;

void _copyValues<K, V>(
  Map<K, V> from,
  Map<K, V?> to,
  bool recursive,
  bool acceptNull,
) {
  for (var MapEntry(:key, :value) in from.entries) {
    if (value == null && !acceptNull) continue;
    if (recursive && value is Map) {
      var existing = to[key];
      if (existing is Map || value is Map<K, V>) {
        var maps = <Map>[if (existing is Map) existing, value];
        // Keep the outer key and value types when every map fits them.
        var merged = maps.every((m) => m is Map<K, V>)
            ? mergeMap<K, V>(maps.cast<Map<K, V>>(), acceptNull: acceptNull)
            : mergeMap(maps, acceptNull: acceptNull);
        if (merged case V merged) {
          to[key] = merged;
          continue;
        }
      }
    }
    to[key] = value;
  }
}

/// Merges the values of the given maps together.
///
/// `recursive` is set to `true` by default. If set to `true`,
/// then nested maps will also be merged. Otherwise, nested maps
/// will overwrite others.
///
/// `acceptNull` is set to `false` by default. If set to `false`,
/// then if the value on a map is `null`, it will be ignored, and
/// that `null` will not be copied.
///
/// Merged nested maps are new maps. They have the key and value types [K] and [V] when every
/// map merged into them fits those types, and `Map<dynamic, dynamic>` otherwise. A nested map
/// is only merged if the result is a valid [V]; otherwise it overwrites the earlier one.
/// A nested map that is not merged with another, and does not fit `Map<K, V>`, is put into
/// the result as-is, so the result and the input share it.
Map<K, V> mergeMap<K, V>(
  Iterable<Map<K, V>> maps, {
  bool recursive = true,
  bool acceptNull = false,
}) {
  var result = <K, V>{};
  for (var map in maps) {
    _copyValues(map, result, recursive, acceptNull);
  }
  return result;
}
