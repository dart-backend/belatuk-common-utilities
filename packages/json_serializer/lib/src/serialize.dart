part of '../belatuk_json_serializer.dart';

/// Serializes any arbitrary Dart datum to JSON. Supports schema validation.
String serialize(dynamic value) {
  var serialized = serializeObject(value);
  logger.finest(() => 'Serialization result: $serialized');
  return json.encode(serialized);
}

/// The lists, maps and objects being serialized right now, to detect cycles.
final _serializing = Set<Object>.identity();

/// Transforms any Dart datum into a value acceptable to json.encode.
///
/// Throws a [JsonCyclicError] if [value] contains itself, such as a parent
/// and child that point to each other.
dynamic serializeObject(dynamic value) {
  if (_isPrimitive(value)) {
    logger.finest(() => "Serializing primitive value: $value");
    return value;
  } else if (value is DateTime) {
    logger.finest(() => "Serializing this DateTime: $value");
    return value.toIso8601String();
  }

  if (!_serializing.add(value)) {
    throw JsonCyclicError(value);
  }
  try {
    if (value is Iterable) {
      logger.finest(() => "Serializing this Iterable: $value");
      return value.map(serializeObject).toList();
    } else if (value is Map) {
      logger.finest(() => "Serializing this Map: $value");
      return serializeMap(value);
    } else {
      return serializeObject(reflection.serialize(value, serializeObject));
    }
  } finally {
    _serializing.remove(value);
  }
}

/// Recursively transforms a Map and its children into JSON-serializable data.
///
/// JSON keys must be strings, so other keys are converted: a [DateTime] to
/// its ISO 8601 string, as values are, and anything else with `toString`.
Map serializeMap(Map value) {
  Map outputMap = {};
  value.forEach((key, value) {
    var outputKey = key is DateTime ? key.toIso8601String() : key.toString();
    outputMap[outputKey] = serializeObject(value);
  });
  return outputMap;
}
