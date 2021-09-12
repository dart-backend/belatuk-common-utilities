# Belatuk Code Buffer

[![version](https://img.shields.io/badge/pub-v3.0.1-brightgreen)](https://pub.dev/packages/belatuk_code_buffer)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![License](https://img.shields.io/github/license/dart-backend/belatuk-common-utilities)](https://github.com/dart-backend/belatuk-common-utilities/packages/code_buffer/LICENSE)

**Replacement of `package:code_buffer` with breaking changes to support NNBD.**

An advanced StringBuffer geared toward generating code, and source maps.

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  belatuk_code_buffer: ^3.0.0
```

## Usage

Use a `CodeBuffer` just like any regular `StringBuffer`:

```dart
String someFunc() {
    var buf = CodeBuffer();
    buf
      ..write('hello ')
      ..writeln('world!');
    return buf.toString();
}
```

However, a `CodeBuffer` supports indentation.

```dart
void someOtherFunc() {
  var buf = CodeBuffer();
  // Custom options...
  var buf = CodeBuffer(newline: '\r\n', space: '\t', trailingNewline: true);
  
  // Any following lines will have an incremented indentation level...
  buf.indent();
  
  // And vice-versa:
  buf.outdent();
}
```

`CodeBuffer` instances keep track of every `SourceSpan` they create.
This makes them useful for codegen tools, or to-JS compilers.

```dart
void someFunc(CodeBuffer buf) {
  buf.write('hello');
  expect(buf.lastLine.text, 'hello');
  
  buf.writeln('world');
  expect(buf.lastLine.lastSpan.start.column, 5);
}
```

You can copy a `CodeBuffer` into another, heeding indentation rules:

```dart
void yetAnotherFunc(CodeBuffer a, CodeBuffer b) {
  b.copyInto(a);
}
```
