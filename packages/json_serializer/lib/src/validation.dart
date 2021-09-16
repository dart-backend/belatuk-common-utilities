part of belatuk_json_serializer;

/// Thrown when schema validation fails.
class JsonValidationError implements Exception {
  //final Schema schema;
  final dynamic invalidData;
  final String cause;

  const JsonValidationError(
      this.cause, this.invalidData); //, Schema this.schema);
}

/// Specifies a schema to validate a class with.
class WithSchema {
  final Map schema;

  const WithSchema(this.schema);
}

/// Specifies a schema to validate a class with.
class WithSchemaUrl {
  final String schemaUrl;

  const WithSchemaUrl(this.schemaUrl);
}
