import 'package:belatuk_code_buffer/belatuk_code_buffer.dart';
import 'package:test/test.dart';

/// Use a `CodeBuffer` just like any regular `StringBuffer`:
String someFunc() {
  var buf = CodeBuffer();
  buf
    ..write('hello ')
    ..writeln('world!');
  return buf.toString();
}

/// However, a `CodeBuffer` supports indentation.
void someOtherFunc() {
  var buf = CodeBuffer();

  // Custom options...
  // ignore: unused_local_variable
  var customBuf =
      CodeBuffer(newline: '\r\n', space: '\t', trailingNewline: true);

  // Without whitespace..
  // ignore: unused_local_variable
  var minifyingBuf = CodeBuffer.noWhitespace();

  // Any following lines will have an incremented indentation level...
  buf.indent();

  // And vice-versa:
  buf.outdent();
}

/// `CodeBuffer` instances keep track of every `SourceSpan` they create.
//This makes them useful for codegen tools, or to-JS compilers.
void yetAnotherOtherFunc(CodeBuffer buf) {
  buf.write('hello');
  expect(buf.lastLine!.text, 'hello');

  buf.writeln('world');
  expect(buf.lastLine!.lastSpan!.start.column, 5);
}

/// You can copy a `CodeBuffer` into another, heeding indentation rules:
void yetEvenAnotherFunc(CodeBuffer a, CodeBuffer b) {
  b.copyInto(a);
}
