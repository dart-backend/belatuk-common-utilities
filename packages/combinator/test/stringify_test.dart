import 'package:belatuk_code_buffer/belatuk_code_buffer.dart';
import 'package:belatuk_combinator/belatuk_combinator.dart';
import 'package:test/test.dart';

String stringify(Parser parser) {
  var buffer = CodeBuffer();
  parser.stringify(buffer);
  return buffer.toString();
}

void main() {
  test('grammar', () {
    var parser = any([match('a'), match('b')]);
    expect(
      stringify(parser),
      'any(2) (\n  #1:\n    match(a)\n  #2:\n    match(b)\n)',
    );
  });

  group('reference', () {
    test('prints its parser the first time, numbered', () {
      var r = reference<String>()..parser = match('a');
      expect(stringify(r), 'reference #1 (\n  match(a)\n)');
    });

    test('prints only its number when it appears again', () {
      var r = reference<String>()..parser = match('a');
      var output = stringify(any([r, r]));
      expect('match(a)'.allMatches(output), hasLength(1));
      expect(output, contains('reference #1 (printed above)'));
    });

    test('numbers different references separately', () {
      var a = reference<String>()..parser = match('a');
      var b = reference<String>()..parser = match('b');
      var output = stringify(any([a, b, a, b]));
      expect(output, contains('reference #1 (printed above)'));
      expect(output, contains('reference #2 (printed above)'));
    });

    test('prints in full again in each call', () {
      var r = reference<String>()..parser = match('a');
      expect(stringify(r), stringify(r));
    });

    test('prints in full again in the same buffer, and after clear()', () {
      var r = reference<String>()..parser = match('a');
      var buffer = CodeBuffer();
      r.stringify(buffer);
      r.stringify(buffer);
      expect('match(a)'.allMatches(buffer.toString()), hasLength(2));
      buffer.clear();
      r.stringify(buffer);
      expect(buffer.toString(), 'reference #1 (\n  match(a)\n)');
    });

    test('an undefined reference prints no number', () {
      expect(stringify(reference<String>()), '(undefined reference <String>)');
    });

    test('a reference containing itself is printed once', () {
      var r = reference<String>();
      r.parser = any([match('a'), r]);
      var output = stringify(r);
      expect('match(a)'.allMatches(output), hasLength(1));
      expect(output, contains('reference #1 (printed above)'));
    });
  });
}
