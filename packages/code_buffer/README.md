# Belatuk Code Buffer

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/belatuk_code_buffer?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![License](https://img.shields.io/github/license/dart-backend/belatuk-common-utilities)](https://github.com/dart-backend/belatuk-common-utilities/blob/main/packages/code_buffer/LICENSE)

A `StringBuffer` for generating source code. A `CodeBuffer` indents lines for you, lets you choose the indentation and line break characters, and records a `SourceSpan` for every line and every piece of text written, which you can use to build source maps.

## Installation

```yaml
dependencies:
  belatuk_code_buffer: ^6.0.0
```

## Writing code

`CodeBuffer` implements `StringBuffer`, so `write`, `writeln`, `writeAll`, `writeCharCode` and `clear` work as usual. `indent` and `outdent` change the indentation of the lines that follow.

```dart
import 'package:belatuk_code_buffer/belatuk_code_buffer.dart';

void main() {
  var buf = CodeBuffer()
    ..writeln('class Point {')
    ..indent()
    ..writeln('final int x;')
    ..writeln()
    ..writeln('const Point(this.x);')
    ..outdent()
    ..writeln('}');

  print(buf);
}
```

This prints:

```text
class Point {
  final int x;

  const Point(this.x);
}
```

A line's indentation is fixed when its first text is written, so calling `indent` part way through a line only affects the next one. Blank lines are never indented. `outdent` does nothing once the indentation level is `0`.

Unlike a `StringBuffer`, `toString()` joins lines with line breaks but does not end the last line with one, unless `trailingNewline` is `true`.

```dart
var buf = CodeBuffer()
  ..writeln('a')
  ..writeln('b');
print(buf.toString() == 'a\nb'); // true
```

## Options

| Parameter | Default | Meaning |
| --- | --- | --- |
| `space` | `'  '` (two spaces) | The text written once per indentation level, such as `'\t'` |
| `newline` | `'\n'` | The text written between lines, such as `'\r\n'` |
| `trailingNewline` | `false` | Whether to write `newline` after the last line |
| `sourceUrl` | `null` | The source URL given to every span the buffer creates |

```dart
var windows = CodeBuffer(newline: '\r\n', space: '\t', trailingNewline: true);
```

`CodeBuffer.noWhitespace()` writes no indentation and no line breaks, which is useful for minified output.

```dart
var buf = CodeBuffer.noWhitespace()
  ..writeln('a();')
  ..indent()
  ..writeln('b();');
print(buf); // a();b();
```

## Lines and source spans

`lines` lists the buffer's lines as `CodeBufferLine` objects, and `lastLine` is the most recent one, or `null` for an empty buffer.

| `CodeBufferLine` member | Meaning |
| --- | --- |
| `text` | The text of the line, without indentation |
| `indentationLevel` | The line's indentation level |
| `span` | A `SourceSpan` covering the line's text |
| `lastSpan` | A `SourceSpan` covering the text written by the last `write` call on the line |
| `sourceMappings` | A `Map<SourceSpan, SourceSpan>` for your own source mapping data |

Lines and columns are zero-based. Each span's offset is the position of its text in `toString()`, and `length` is the length of `toString()`, both counting indentation and line breaks.

```dart
var buf = CodeBuffer(sourceUrl: 'out.js')
  ..writeln('var a = 1;')
  ..write('var b = ')
  ..write('2');

var span = buf.lastLine!.lastSpan!;
print(span.text); // 2
print(span.start.line); // 1
print(span.start.column); // 8
print(span.start.offset); // 19
print(span.start.toolString); // out.js:2:9
```

## Source mappings

A code generator can record where each piece of output came from. The buffer does not fill in `sourceMappings` itself: store the span of the generated text as the key and the span of the original source as the value, then use them to build a source map.

```dart
import 'package:belatuk_code_buffer/belatuk_code_buffer.dart';
import 'package:source_span/source_span.dart';

void main() {
  var input = SourceFile.fromString('let x = 1', url: 'input.txt');
  var original = input.span(4, 5); // x

  var buf = CodeBuffer(sourceUrl: 'output.js')
    ..write('var ')
    ..write('x');
  var line = buf.lastLine!;
  line.sourceMappings[line.lastSpan!] = original;
}
```

## Copying buffers

`copyInto` appends the lines of one buffer to another, adding the target's current indentation to each line. Copied lines always start on a new line, and the last one is ended, so writing can continue below them.

```dart
var body = CodeBuffer()..writeln('return 1;');

var function = CodeBuffer()
  ..writeln('int f() {')
  ..indent();
body.copyInto(function);
function
  ..outdent()
  ..writeln('}');

print(function);
```

This prints:

```text
int f() {
  return 1;
}
```

Each copied line keeps its `sourceMappings`, unchanged. Their spans are not moved to the line's new position, because the buffer cannot tell which of them refer to the generated code.

## Limitations

Line breaks inside the text you pass to `write` are written as they are: the text after them is not indented and does not start a new `CodeBufferLine`, so the line and column numbers of later spans no longer match the output. Offsets stay correct. Use `writeln` to end lines.

## Upgrading from 5.x

Version 6.0.0 makes `length` and span offsets match `toString()`, counting indentation and the full `newline`, and `writeln()` on an empty line now adds a blank line instead of being ignored. See the [changelog](CHANGELOG.md) for the full list.
