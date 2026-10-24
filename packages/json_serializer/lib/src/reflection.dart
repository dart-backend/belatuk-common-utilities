library;

import 'dart:mirrors';

import '../belatuk_json_serializer.dart';

const Symbol hashCodeSymbol = #hashCode;
const Symbol runtimeTypeSymbol = #runtimeType;

typedef Serializer = dynamic Function(dynamic value);
typedef Deserializer = dynamic Function(dynamic value, {Type? outputType});

List<Symbol> _findGetters(ClassMirror classMirror) {
  List<Symbol> result = [];

  classMirror.instanceMembers.forEach((
    Symbol symbol,
    MethodMirror methodMirror,
  ) {
    // Private getters, such as a `_cache`, are internal state, not data.
    if (methodMirror.isGetter &&
        !methodMirror.isPrivate &&
        symbol != hashCodeSymbol &&
        symbol != runtimeTypeSymbol) {
      logger.finest(() => "Found getter on instance: $symbol");
      result.add(symbol);
    }
  });

  return result;
}

dynamic serialize(dynamic value, Serializer serializer) {
  logger.finest(() => "Serializing this value via reflection: $value");
  Map result = {};
  InstanceMirror instanceMirror = reflect(value);
  ClassMirror classMirror = instanceMirror.type;

  // Check for toJson
  if (classMirror.instanceMembers.containsKey(#toJson)) {
    logger.finest(() => "Running toJson...");
    var result = instanceMirror.invoke(#toJson, []).reflectee;
    logger.finest(() => "Result of serialization via reflection: $result");
    return result;
  }

  // A getter that throws, or a value that cannot be serialized, fails the
  // whole call, so a field is never silently left out of the output.
  for (Symbol symbol in _findGetters(classMirror)) {
    String name = MirrorSystem.getName(symbol);

    try {
      var valueForSymbol = instanceMirror.getField(symbol).reflectee;
      result[name] = serializer(valueForSymbol);
      logger.finest(() => "Set $name to $valueForSymbol");
    } catch (e, st) {
      logger.severe("Could not serialize field $name.", e, st);
      rethrow;
    }
  }

  logger.finest(() => "Result of serialization via reflection: $result");

  return result;
}

/// Whether [type] puts no constraint on a value, so it needs no conversion.
bool _isUntyped(TypeMirror type) =>
    type == currentMirrorSystem().dynamicType ||
    !type.hasReflectedType ||
    type.reflectedType == Object ||
    type.reflectedType == _nullableObject;

final Type _nullableObject = _typeOf<Object?>();

Type _typeOf<T>() => T;

/// Whether [type] is [target], ignoring nullability and type arguments.
bool _isClass(TypeMirror type, Type target) =>
    type is ClassMirror && type.originalDeclaration == reflectClass(target);

/// Converts a JSON scalar to [outputType] where JSON has no exact match: an
/// ISO 8601 string to a [DateTime], as [serialize] writes it, and an [int] to
/// a [double], since JSON does not tell `1` and `1.0` apart.
dynamic _deserializeScalar(dynamic value, TypeMirror outputType) {
  if (value is String && _isClass(outputType, DateTime)) {
    return DateTime.parse(value);
  } else if (value is int && _isClass(outputType, double)) {
    return value.toDouble();
  }
  return value;
}

dynamic deserialize(dynamic value, Type outputType, Deserializer deserializer) {
  logger.finest(() => "About to deserialize $value to a $outputType");

  try {
    var outputMirror = reflectType(outputType);
    if (value == null || _isUntyped(outputMirror)) {
      return deserializer(value);
    } else if (value is List) {
      List<TypeMirror> typeArguments = outputMirror.typeArguments;

      Iterable it;

      // A list with no element type, or `dynamic` or `Object` elements, as in
      // a field declared as `List items`, keeps its elements as they decode.
      if (typeArguments.isEmpty || _isUntyped(typeArguments[0])) {
        return value.map(deserializer).toList();
      } else {
        it = value.map(
          (item) =>
              deserializer(item, outputType: typeArguments[0].reflectedType),
        );
      }

      logger.finest(
        () =>
            'Casting list elements to ${typeArguments[0].reflectedType} via List.from',
      );

      var mirror = reflectType(List, [typeArguments[0].reflectedType]);

      if (mirror is ClassMirror) {
        var output = mirror.newInstance(#from, [it]).reflectee;
        logger.finest(() => 'Casted list type: ${output.runtimeType}');
        return output;
      } else {
        throw ArgumentError(
          '${typeArguments[0].reflectedType} is not a class.',
        );
      }
    } else if (value is Map) {
      return _deserializeFromJsonByReflection(value, deserializer, outputType);
    } else {
      return _deserializeScalar(deserializer(value), outputMirror);
    }
  } catch (e, st) {
    logger.severe('Deserialization failed.', e, st);
    rethrow;
  }
}

/// Uses mirrors to deserialize an object.
dynamic _deserializeFromJsonByReflection(
  dynamic data,
  Deserializer deserializer,
  Type outputType,
) {
  // Check for fromJson
  var typeMirror = reflectType(outputType);

  if (typeMirror is! ClassMirror) {
    throw ArgumentError('$outputType is not a class.');
  }

  var type = typeMirror;
  var fromJson = Symbol('${MirrorSystem.getName(type.simpleName)}.fromJson');

  var decl = type.declarations[fromJson];
  if (decl is MethodMirror && decl.isConstructor) {
    logger.finest(() => "Running fromJson...");
    var result = type.newInstance(#fromJson, [data]).reflectee;

    logger.finest(() => "Result of deserialization via reflection: $result");
    return result;
  }

  ClassMirror classMirror = type;

  if (classMirror.isSubclassOf(reflectClass(Map))) {
    var typeArguments = classMirror.typeArguments;

    if (typeArguments.isEmpty ||
        classMirror.typeArguments.every(
          (t) => t == currentMirrorSystem().dynamicType,
        )) {
      return data;
    } else {
      var mapType = reflectType(
        Map,
        typeArguments.map((t) => t.reflectedType).toList(),
      ) as ClassMirror;
      logger.finest(() => 'Casting this map $data to Map of [$typeArguments]');
      var output = mapType.newInstance(Symbol(''), []).reflectee;

      // Each value is converted to the map's value type, so a JSON object
      // read as `Map<String, Foo>` holds `Foo` instances, not raw maps.
      var valueType = typeArguments.length == 2 ? typeArguments[1] : null;
      for (var key in data.keys) {
        output[key] = valueType == null || _isUntyped(valueType)
            ? deserializer(data[key])
            : deserializer(data[key], outputType: valueType.reflectedType);
      }

      logger.finest(() => 'Output: $output of type ${output.runtimeType}');
      return output;
    }
  } else {
    InstanceMirror instanceMirror;
    try {
      instanceMirror = classMirror.newInstance(Symbol(""), []);
    } on NoSuchMethodError {
      throw ArgumentError(
        '$outputType cannot be deserialized: it needs a constructor that takes '
        'no arguments, or a fromJson constructor.',
      );
    }

    for (var key in data.keys) {
      // A key with no matching setter, such as an extra field in the JSON, is
      // skipped on purpose. Any other error setting a field is thrown, so the
      // caller never gets a half-filled object.
      var setter = classMirror.instanceMembers[Symbol('$key=')];
      if (setter == null) {
        logger.finest(() => "Skipping $key, which has no setter.");
        continue;
      }

      try {
        logger.finest(() => "Now deserializing value for $key");
        logger.finest(() => "data[\"$key\"] = ${data[key]}");
        var deserializedValue = deserializer(data[key]);

        logger.finest(
          () =>
              "I want to set $key to the following ${deserializedValue.runtimeType}: $deserializedValue",
        );
        // Get target type of the setter's parameter
        Type requiredType = setter.parameters.first.type.reflectedType;
        if (data[key].runtimeType != requiredType) {
          logger.finest(() => "Currently, $key is a ${data[key].runtimeType}.");
          logger.finest(() => "However, $key must be a $requiredType.");

          deserializedValue = deserializer(
            deserializedValue,
            outputType: requiredType,
          );
        }

        logger.finest(
          () =>
              "Final deserialized value for $key: $deserializedValue <${deserializedValue.runtimeType}>",
        );
        instanceMirror.setField(Symbol(key.toString()), deserializedValue);

        logger.finest(() => "Success! $key has been set to $deserializedValue");
      } catch (e, st) {
        logger.severe('Could not set value for field $key.', e, st);
        rethrow;
      }
    }

    return instanceMirror.reflectee;
  }
}
