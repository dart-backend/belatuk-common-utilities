# Belatuk Combinator

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/belatuk_combinator?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![License](https://img.shields.io/github/license/dart-backend/belatuk-common-utilities)](https://github.com/dart-backend/belatuk-common-utilities/blob/main/packages/combinator/LICENSE)

Packrat parser combinators for Dart: small parsers that you combine into larger ones to turn text into typed values. Every result carries the `FileSpan` of the text it matched, failures report errors with locations and severities, and results are memoized by parser and position during a parse.

## Installation

```yaml
dependencies:
  belatuk_combinator: ^6.0.0
  string_scanner: ^1.1.0
```

Parsers read from a `SpanScanner`, which comes from the `string_scanner` package, so add that package too.

## Parsing text

`match` creates a parser for a `String` or `RegExp`. Call `parse` with a `SpanScanner` to run it.

```dart
import 'package:belatuk_combinator/belatuk_combinator.dart';
import 'package:string_scanner/string_scanner.dart';

void main() {
  var number = match<int>(
    RegExp(r'[0-9]+'),
    errorMessage: 'Expected a number.',
  ).value((r) => int.parse(r.span!.text));

  var result = number.parse(SpanScanner('42'));
  print(result.successful); // true
  print(result.value); // 42
}
```

`parse` returns a `ParseResult`:

| Member | Meaning |
| --- | --- |
| `successful` | Whether the parser matched |
| `value` | The parsed value, or `null` |
| `span` | The `FileSpan` of the matched text |
| `errors` | The `SyntaxError`s reported |
| `scanner` | The scanner, positioned after the matched text |

A parser only has to match the start of the text. To require the whole input, check that the scanner is done.

```dart
var scanner = SpanScanner('7 apples');
var result = number.space().parse(scanner);
print(result.value); // 7
print(scanner.isDone); // false
print(scanner.rest); // apples
```

## Values

`match` produces no value, only a span. Give a parser a value with one of these:

| Method | Result |
| --- | --- |
| `value(f)` | Sets the value, keeping the parser's type |
| `map<U>(f)` | Converts the result to a value of type `U` |
| `change<U>(f)` | Replaces the whole `ParseResult` |
| `cast<U>()`, `castDynamic()` | Changes the parser's type |

Each function receives the `ParseResult`, so it can read `r.span`, `r.value` and `r.scanner`. The functions passed to `value` and `map` are only called when the parser matched, and the one passed to `change` is always called.

```dart
var word = match<String>(RegExp(r'[a-z]+')).value((r) => r.span!.text);
var length = word.map((r) => r.value!.length);
print(length.parse(SpanScanner('hello')).value); // 5
```

## Sequences

`chain` matches parsers one after another, and its value is the list of their values. A parser without a value, such as `match` or an optional parser that matched nothing, adds `null` to the list. Give `chain` a nullable type, such as `chain<int?>`, when that can happen: with a non-nullable type, it throws a `StateError` that says so. `then` chains two parsers.

```dart
var name = match<String>(RegExp(r'[a-z]+')).value((r) => r.span!.text);
var assignment = chain([name.space(), match('=').space(), number]);
print(assignment.parse(SpanScanner('x = 1')).value); // [x, null, 1]
```

The `tuple2` to `tuple7` functions match a sequence of parsers with different types, and produce a `Tuple2` to `Tuple7` from the `tuple` package.

```dart
var pair = tuple3(name.space(), match('=').space(), number);
var tuple = pair.parse(SpanScanner('x = 1')).value!;
print(tuple.item1); // x
print(tuple.item3); // 1
```

`a.and(b)`, or `a & b`, matches both parsers but keeps only the value of `a`. `b` can be a parser of any type.

## Alternatives

`any` tries parsers in order and uses the first one that matches. `longest` tries all of them and uses the one that matches the most text. `a | b` and `a.or(b)` are the same as `any([a, b])`. If `b` has a different type from `a`, its values are cast to `a`'s type, and one that does not fit throws a `TypeError`.

```dart
Parser<String> keyword(String text) => match<String>(text).value((r) => text);

var first = any([keyword('in'), keyword('int')]);
var best = longest([keyword('in'), keyword('int')]);
print(first.parse(SpanScanner('int')).value); // in
print(best.parse(SpanScanner('int')).value); // int
```

## Repetition

| Method | Matches |
| --- | --- |
| `opt()` | Zero or one time. The value is `null` when nothing matches. With `backtrack: false`, a failed attempt keeps the text it consumed |
| `star()` | Zero or more times. The value is an empty list when nothing matches |
| `plus()` | One or more times |
| `times(n)` | Exactly `n` times, or at least `n` times with `exact: false` |
| `separatedBy(separator)` | One or more times, separated by `separator`, whose values are dropped |

All but `opt` return a `ListParser`, whose value is a list. Parsers without a value add nothing to the list.

```dart
var numbers = number.space().plus();
print(numbers.parse(SpanScanner('1 2 3')).value); // [1, 2, 3]

var csv = number.separatedBy(match(',').space());
print(csv.parse(SpanScanner('1, 2, 3')).value); // [1, 2, 3]
```

A `ListParser` has these methods to process its list:

| Method | Value |
| --- | --- |
| `first()`, `last()`, `index(i)` | One element of the list |
| `reduce(combine)` | The elements combined with `List.reduce` |
| `sort(compare)` | The list, sorted |
| `where(test)` | The elements that pass `test` |
| `flatten()` | The matched text, as a `String` |

```dart
var total = number.space().plus().reduce((a, b) => a + b);
print(total.parse(SpanScanner('1 2 3')).value); // 6

var letters = match(RegExp(r'[a-z]')).plus().flatten();
print(letters.parse(SpanScanner('abc1')).value); // abc
```

## Whitespace and delimiters

`space()` consumes any spaces, tabs and line breaks after a parser, and `trail(pattern)` consumes one match of `pattern` after it, if there is one. Neither consumes text before the parser. The span of the result includes the consumed text.

`surroundedBy(left, [right])` matches a parser between two others, and keeps only its value. `parenthesized()` matches a parser in parentheses, and `maybeParenthesized()` matches it with or without them.

```dart
print(number.parenthesized().parse(SpanScanner('(4)')).value); // 4
print(number.surroundedBy(match('"')).parse(SpanScanner('"4"')).value); // 4
```

`separatedByComma()` is `separatedBy` with a comma and optional spaces. `surroundedByCurlyBraces` and `surroundedBySquareBrackets` match a parser, or nothing, between braces or brackets, and give `defaultValue` when they are empty.

```dart
var array = number.separatedByComma().surroundedBySquareBrackets(
  defaultValue: [],
);
print(array.parse(SpanScanner('[1, 2]')).value); // [1, 2]
print(array.parse(SpanScanner('[]')).value); // []
```

## Errors

A failed parse returns `SyntaxError`s, each with a `message`, a `severity` and the `span` where it happened. `toolString` formats an error with its location, and the span's `highlight()` shows it in the source.

```dart
var scanner = SpanScanner('x', sourceUrl: 'input.txt');
var result = number.parse(scanner);

for (var error in result.errors) {
  print(error.toolString); // error: input.txt:1:1: Expected a number.
  print(error.span!.highlight());
}
```

Parsers report errors as follows:

| Parser | Error message |
| --- | --- |
| `match` | `errorMessage`, or `Expected "<pattern>".` |
| `any`, `longest` | `errorMessage`, or `No match found for <n> alternative(s)`. Pass `errorMessage: false` to report none |
| `times` | `tooFew` and `tooMany`, which default to `Too few` and `Too many`, as `plus` and `star` always do |
| `error()` | Adds `errorMessage` to the errors of the parser it wraps, when that parser fails |

`any` and `longest` pass on the errors of a failed alternative only when it is wrapped with `error()`. `chain` stops at the first element that fails and returns that element's errors. With `failFast: false` it carries on instead, and passes on only the errors of failed elements wrapped with `error()`. Use `foldErrors()` to keep only the first error at each position.

```dart
var statement = any([
  match('let').error(errorMessage: 'Expected a declaration.'),
  match('print').error(errorMessage: 'Expected a statement.'),
], errorMessage: false);

var result = statement.parse(SpanScanner('x'));
print(result.errors.map((e) => e.message));
// (Expected "let"., Expected a declaration., Expected "print"., Expected a statement.)
```

Most methods that report errors take a `severity`: `SyntaxErrorSeverity.error` (the default), `warning`, `info` or `hint`. `toolString` starts with `warning` for warnings and with `error` for every other severity.

### Validating values

`check` fails when a value does not satisfy a `Matcher` from the `matcher` package, which you need to add as a dependency.

```dart
import 'package:matcher/matcher.dart';

var port = number.check(lessThan(65536));
var result = port.parse(SpanScanner('70000'));
print(result.errors.first.message); // Expected a value less than <65536>.
```

`negate()`, or `~parser`, succeeds where a parser fails, and fails with `errorMessage` (by default `Negate error`) where it matches.

## Recursive grammars

A grammar that refers to itself needs a `reference`. Use it like any other parser, then assign the real parser to it once the grammar is built. Parsing with a reference that has no parser, or assigning a second parser, throws a `StateError`.

```dart
var value = reference<Object>();
var list = value
    .space()
    .separatedBy(match(',').space())
    .surroundedBy(match('[').space(), match(']').space());
value.parser = any<Object>([number, list]);

print(value.parse(SpanScanner('[1, [2, 3], 4]')).value); // [1, [2, 3], 4]
```

Left-recursive rules, such as `difference := difference '-' number | number`, parse all of their input and group from the left, so `10-2-3` is `(10-2)-3`. Two levels of left recursion give operator precedence:

```dart
var expr = reference<int>(), term = reference<int>();
var factor = any<int>([number, expr.parenthesized()]);

term.parser = any<int>([
  chain<dynamic>([term, match('*'), factor])
      .map((r) => (r.value![0] as int) * (r.value![2] as int)),
  factor,
]);
expr.parser = any<int>([
  chain<dynamic>([expr, match('+'), term])
      .map((r) => (r.value![0] as int) + (r.value![2] as int)),
  term,
]);

print(expr.parse(SpanScanner('2+3*4')).value); // 14
```

## Other combinators

| Method | Effect |
| --- | --- |
| `cache()` | Returns the parser itself. Every parser's result at each position is already cached during one parse |
| `maxDepth(depth)` | Fails when the parser is nested more than `depth` levels deep |
| `safe()` | Turns an exception thrown during parsing into an error. After one exception, the parser always fails |
| `forward(n)`, `back(n)` | Moves the scanner `n` characters forward or back after a successful match |

## Printing a grammar

`stringify` writes a description of a parser to a `CodeBuffer` from the `belatuk_code_buffer` package, which helps when debugging a grammar.

```dart
import 'package:belatuk_code_buffer/belatuk_code_buffer.dart';

var buffer = CodeBuffer();
any([match('a'), match('b').opt()]).stringify(buffer);
print(buffer);
```

This prints:

```text
any(2) (
  #1:
    match(a)
  #2:
    optional (
      match(b)
    )
)
```

A `reference` is numbered and printed in full the first time it appears in a call to `stringify`, as `reference #1 (...)`, and as `reference #1 (printed above)` after that. So a grammar that refers to itself is printed without recursing forever.

## Limitations

Results are cached by parser and position for the length of one parse, regardless of how deeply nested the parser was. So a `maxDepth` parser that fails because it was reached too deep in the grammar also fails if it is reached again at the same position from a shallower depth.

## Upgrading from 5.x

Version 6.0.0 changes several results. `chain`, `then` and the `tupleN` functions give `null` for an element without a value, instead of the string `'NULL'`, and `chain` with a non-nullable type throws a `StateError` in that case. `star()` gives an empty list instead of `null`. Left-recursive rules now parse all of their input, which changes the result of grammars that relied on them stopping after one step. References are printed with numbers, and `Reference.printed` is removed. See the [changelog](CHANGELOG.md) for the full list.
