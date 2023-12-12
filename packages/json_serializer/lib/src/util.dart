part of '../belatuk_json_serializer.dart';

bool _isPrimitive(value) {
  return value is num || value is bool || value is String || value == null;
}
