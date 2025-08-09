import 'package:logging/logging.dart';
import 'package:belatuk_json_serializer/belatuk_json_serializer.dart';
import 'package:stack_trace/stack_trace.dart';

void printRecord(LogRecord rec) {
  print(rec);
  if (rec.error != null) print(rec.error);
  if (rec.stackTrace != null) print(Chain.forTrace(rec.stackTrace!).terse);
}

class SampleNestedClass {
  String? bar;

  SampleNestedClass([this.bar]);
}

class SampleClass {
  String? hello;
  List<SampleNestedClass> nested = [];

  SampleClass([this.hello]);
}

@WithSchemaUrl(
  "http://raw.githubusercontent.com/SchemaStore/schemastore/master/src/schemas/json/babelrc.json",
)
class BabelRc {
  List<String> presets;
  List<String> plugins;

  BabelRc({this.presets = const [], this.plugins = const []});
}

@WithSchema({
  r"$schema": "http://json-schema.org/draft-04/schema#",
  "title": "Validated Sample Class",
  "description": "Sample schema for validation via JSON God",
  "type": "object",
  "hello": {"description": "A friendly greeting.", "type": "string"},
  "nested": {
    "description": "A list of NestedSampleClass items within this instance.",
    "type": "array",
    "items": {
      "type": "object",
      "bar": {"description": "Filler text", "type": "string"},
    },
  },
  "required": ["hello", "nested"],
})
class ValidatedSampleClass {}
