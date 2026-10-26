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
    test('prints its parser the first time, without a marker', () {
      var r = reference<String>()..parser = match('a').map((r) => 'a');
      expect(stringify(r), isNot(contains('previously printed reference')));
      expect(stringify(r), contains('match(a)'));
    });

    test('prints a marker when printed again in the same buffer', () {
      var r = reference<String>()..parser = match('a').map((r) => 'a');
      var output = stringify(any([r, r]));
      expect('match(a)'.allMatches(output), hasLength(1));
      expect('(previously printed reference)'.allMatches(output), hasLength(1));
    });

    test('prints in full again in a new buffer', () {
      var r = reference<String>()..parser = match('a').map((r) => 'a');
      expect(stringify(r), stringify(r));
    });

    test('an undefined reference prints no marker', () {
      expect(stringify(reference<String>()), '(undefined reference <String>)');
    });

    test('a reference containing itself does not recurse forever', () {
      var r = reference<String>();
      r.parser = any([match('a').map((r) => 'a'), r]);
      expect(stringify(r), contains('(previously printed reference)'));
    });
  });
}
