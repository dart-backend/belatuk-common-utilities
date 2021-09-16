part of belatuk_json_serializer;

bool _isPrimitive(value) {
  return value is num || value is bool || value is String || value == null;
}
