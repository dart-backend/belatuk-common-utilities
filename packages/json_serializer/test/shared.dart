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

  int get readOnly => 1;

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

class TypedSampleClass {
  DateTime? when;
  DateTime created = DateTime(2000);
  double price = 0;
  Map<String, SampleNestedClass> byName = {};
  List items = [];
}

class ThrowingGetterClass {
  String get broken => throw StateError('broken');
}

class NestedThrowingGetterClass {
  ThrowingGetterClass inner = ThrowingGetterClass();
}

class RequiredArgClass {
  String name;

  RequiredArgClass(this.name);
}

class PrivateStateClass {
  String visible = 'yes';
  // Read through reflection, so the analyzer cannot see the use.
  // ignore: unused_field
  final String _cache = 'hidden';
}

class Node {
  String name;
  Node? parent;
  List<Node> children = [];

  Node(this.name);
}
