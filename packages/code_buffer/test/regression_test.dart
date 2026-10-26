import 'package:belatuk_code_buffer/belatuk_code_buffer.dart';
import 'package:source_span/source_span.dart';
import 'package:test/test.dart';

/// Asserts that every line's span offsets point at its text within [buf].
void expectSpansMatchOutput(CodeBuffer buf) {
  var out = buf.toString();
  for (var line in buf.lines) {
    var span = line.span;
    expect(out.substring(span.start.offset, span.end.offset), line.text);
    var lastSpan = line.lastSpan;
    if (lastSpan != null) {
      expect(
        out.substring(lastSpan.start.offset, lastSpan.end.offset),
        lastSpan.text,
      );
    }
  }
}

void main() {
  group('copyInto', () {
    test('numbers copied lines consecutively', () {
      var a = CodeBuffer()..writeln('a');
      var b = CodeBuffer()
        ..writeln('b1')
        ..writeln('b2')
        ..writeln('b3');
      b.copyInto(a);
      expect(a.lines.map((l) => l.span.start.line), [0, 1, 2, 3]);
      expect(a.toString(), 'a\nb1\nb2\nb3');
      expectSpansMatchOutput(a);
    });

    test('rebases lastSpan offset relative to its line', () {
      var a = CodeBuffer()..writeln('0123456789');
      var b = CodeBuffer()
        ..writeln('x' * 100)
        ..write('foo')
        ..writeln('bar');
      a.indent();
      b.copyInto(a);
      var last = a.lastLine!;
      expect(last.lastSpan!.text, 'bar');
      expect(last.lastSpan!.start.column, 5);
      expect(last.lastSpan!.end.offset, last.span.end.offset);
      expectSpansMatchOutput(a);
    });

    test('uses the real lastSpan column for repeated text', () {
      var a = CodeBuffer()..indent();
      var b = CodeBuffer()
        ..write('foo')
        ..writeln('foo');
      b.copyInto(a);
      expect(a.lastLine!.lastSpan!.start.column, 5);
      expectSpansMatchOutput(a);
    });

    test('into an empty buffer starts at offset 0', () {
      var a = CodeBuffer();
      (CodeBuffer()..writeln('x')).copyInto(a);
      expect(a.lastLine!.span.start.offset, 0);
      expect(a.length, a.toString().length);
    });

    test('does not double count a preceding newline', () {
      var a = CodeBuffer()..writeln('x');
      (CodeBuffer()..writeln('y')).copyInto(a);
      expect(a.lastLine!.span.start.offset, 2);
      expect(a.length, a.toString().length);
    });

    test('into itself', () {
      var a = CodeBuffer()
        ..writeln('a')
        ..writeln('b');
      a.copyInto(a);
      expect(a.toString(), 'a\nb\na\nb');
      expectSpansMatchOutput(a);
    });

    test('copies sourceMappings unchanged', () {
      var original = SourceFile.fromString('foo', url: 'in.dart').span(0, 3);
      var b = CodeBuffer()
        ..write('x = ')
        ..writeln('foo');
      var generated = b.lastLine!.lastSpan!;
      b.lastLine!.sourceMappings[generated] = original;
      var a = CodeBuffer()
        ..writeln('first')
        ..indent();
      b.copyInto(a);
      expect(a.lastLine!.sourceMappings, {generated: original});
    });

    test('does not throw for mappings left of the indentation', () {
      var original = SourceFile.fromString('abc').span(0, 1);
      var b = CodeBuffer(space: '    ')
        ..indent()
        ..writeln('abc');
      b.lastLine!.sourceMappings[original] = original;
      var a = CodeBuffer.noWhitespace();
      b.copyInto(a);
      expect(a.lastLine!.sourceMappings, {original: original});
    });

    test('does not indent copied blank lines', () {
      var b = CodeBuffer()
        ..writeln('a')
        ..writeln()
        ..writeln('b');
      var a = CodeBuffer()..indent();
      b.copyInto(a);
      expect(a.toString(), '  a\n\n  b');
      expectSpansMatchOutput(a);
    });
  });

  group('writeln', () {
    test('does not indent blank lines', () {
      var buf = CodeBuffer()
        ..writeln('{')
        ..indent()
        ..writeln()
        ..writeln('x');
      expect(buf.toString(), '{\n\n  x');
      expect(buf.length, buf.toString().length);
      expectSpansMatchOutput(buf);
    });

    test('keeps blank lines', () {
      var buf = CodeBuffer()
        ..writeln('a')
        ..writeln()
        ..writeln('b');
      expect(buf.toString(), 'a\n\nb');
      expect(buf.lines, hasLength(3));
      expectSpansMatchOutput(buf);
    });

    test('length matches output for multi-char newline', () {
      var buf = CodeBuffer(newline: '\r\n')
        ..writeln('a')
        ..writeln('b');
      expect(buf.length, buf.toString().length);
      expectSpansMatchOutput(buf);
    });

    test('length matches output with trailing newline', () {
      var buf = CodeBuffer(trailingNewline: true)
        ..writeln('a')
        ..writeln('b');
      expect(buf.length, buf.toString().length);
    });

    test('length matches output with noWhitespace', () {
      var buf = CodeBuffer.noWhitespace()
        ..writeln('a')
        ..indent()
        ..writeln('b');
      expect(buf.toString(), 'ab');
      expect(buf.length, 2);
      expectSpansMatchOutput(buf);
    });

    test('offsets include indentation', () {
      var buf = CodeBuffer()
        ..writeln('a')
        ..indent()
        ..writeln('b');
      expect(buf.lastLine!.span.start.offset, 4);
      expect(buf.length, buf.toString().length);
      expectSpansMatchOutput(buf);
    });
  });

  group('write', () {
    test('keeps embedded line breaks unchanged', () {
      var buf = CodeBuffer()
        ..indent()
        ..writeln("s = '''a\nb''';");
      expect(buf.toString(), "  s = '''a\nb''';");
      expect(buf.lines, hasLength(1));
      expectSpansMatchOutput(buf);
    });

    test('keeps embedded line breaks with noWhitespace', () {
      var buf = CodeBuffer.noWhitespace()
        ..write('// comment\n')
        ..write('doThing();');
      expect(buf.toString(), '// comment\ndoThing();');
    });

    test('writeCharCode counts surrogate pairs', () {
      var buf = CodeBuffer()
        ..writeCharCode(0x1F600)
        ..write('a');
      expect(buf.length, 3);
      expect(buf.lastLine!.lastSpan!.start.column, 2);
      expectSpansMatchOutput(buf);
    });
  });

  test('clear resets lastLine', () {
    var buf = CodeBuffer()..write('x');
    buf.clear();
    expect(buf.lastLine, isNull);
  });
}
