import 'dart:io';

import 'package:belatuk_combinator/belatuk_combinator.dart';
import 'package:string_scanner/string_scanner.dart';

Parser jsonGrammar() {
  var expr = reference();

  // Parse a number
  var number = match<num>(
    RegExp(r'-?[0-9]+(\.[0-9]+)?'),
    errorMessage: 'Expected a number.',
  ).value((r) => num.parse(r.span!.text));

  // Parse a string (no escapes supported, because lazy).
  var string = match(
    RegExp(r'"[^"]*"'),
    errorMessage: 'Expected a string.',
  ).value((r) => r.span!.text.substring(1, r.span!.text.length - 1));

  // Parse an array
  var array = expr.space().separatedByComma().surroundedBySquareBrackets(
    defaultValue: [],
  );

  // KV pair
  var keyValuePair = chain([
    string.space(),
    match(':').space(),
    expr.error(errorMessage: 'Missing expression.'),
  ]).map<Map>((r) => {r.value![0]: r.value![2]});

  // Parse an object, merging its key-value pairs into one map.
  var object = keyValuePair
      .separatedByComma()
      .map<Map>((r) => {for (var pair in r.value!) ...pair})
      .surroundedByCurlyBraces(defaultValue: {});

  expr.parser = longest([
    array,
    number,
    string,
    object.error(),
  ], errorMessage: 'Expected an expression.').space();

  return expr.foldErrors();
}

void main() {
  var json = jsonGrammar();

  while (true) {
    stdout.write('Enter some JSON: ');
    var line = stdin.readLineSync();
    if (line == null) break;
    var scanner = SpanScanner(line, sourceUrl: 'stdin');
    var result = json.parse(scanner);

    if (!result.successful) {
      for (var error in result.errors) {
        print(error.toolString);
        print(error.span!.highlight(color: true));
      }
    } else {
      print(result.value);
    }
  }
}
