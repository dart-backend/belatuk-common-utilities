import 'package:belatuk_combinator/belatuk_combinator.dart';
import 'package:test/test.dart';

import 'common.dart';

final number = match<int>(
  RegExp(r'[0-9]+'),
  errorMessage: 'Expected a number',
).map((r) => int.parse(r.span!.text));

void main() {
  test('alternatives sharing a first parser', () {
    var a = match('a');
    var p = any([
      chain([a, match('b')]),
      chain([a, match('c')]),
    ]);
    var result = p.parse(scan('ac'));
    expect(result.successful, isTrue);
    expect(result.span?.text, 'ac');
  });

  group('separatedByComma', () {
    test('one item', () {
      expect(number.separatedByComma().parse(scan('1')).value, [1]);
    });

    test('several items', () {
      expect(number.separatedByComma().parse(scan('1, 2,3')).value, [1, 2, 3]);
    });
  });

  group('surrounded by', () {
    test('empty curly braces give the default value', () {
      var p = number.surroundedByCurlyBraces(defaultValue: 0);
      expect(p.parse(scan('{}')).value, 0);
      expect(p.parse(scan('{5}')).value, 5);
    });

    test('empty square brackets give the default value', () {
      var p = number.separatedByComma().surroundedBySquareBrackets(
        defaultValue: [],
      );
      expect(p.parse(scan('[]')).value, isEmpty);
      expect(p.parse(scan('[1,2]')).value, [1, 2]);
    });
  });

  group('chain', () {
    test('an element with no value is null', () {
      var result = chain<int?>([number, number.opt()]).parse(scan('1'));
      expect(result.value, [1, null]);
    });

    test('a non-nullable type with an empty element throws a clear error', () {
      expect(
        () => chain<int>([number, number.opt()]).parse(scan('1')),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('int?'),
          ),
        ),
      );
    });

    test('tuple with an empty element', () {
      var result = tuple2(number, match('x').opt()).parse(scan('1'));
      expect(result.value?.item1, 1);
      expect(result.value?.item2, isNull);
    });
  });

  test('cache does not reuse results from another parse', () {
    var cached = number.cache();
    expect(cached.parse(scan('1')).value, 1);
    expect(cached.parse(scan('2')).value, 2);
  });

  test('cache moves the scanner when it reuses a result', () {
    var n = number.cache();
    var p = any([
      chain([n, match('+')]),
      chain([n, match('-')]),
    ]);
    expect(p.parse(scan('1-')).span?.text, '1-');
  });

  test('star gives an empty list when nothing matches', () {
    expect(number.star().parse(scan('x')).value, isEmpty);
    expect(number.space().star().parse(scan('1 2')).value, [1, 2]);
  });

  test('opt(backtrack: false) keeps what a failed parse consumed', () {
    var ab = chain([match('a'), match('b')]);
    var backtracking = chain<dynamic>([ab.opt(), match('a')]);
    var greedy = chain<dynamic>([ab.opt(backtrack: false), match('a')]);
    expect(backtracking.parse(scan('a')).successful, isTrue);
    expect(greedy.parse(scan('a')).successful, isFalse);
  });

  group('left recursion', () {
    int op(ParseResult<List> r, int Function(int, int) f) =>
        f(r.value![0] as int, r.value![2] as int);

    test('parses the whole input, grouping from the left', () {
      var expr = reference<int>();
      expr.parser = any<int>([
        chain<dynamic>([expr, match('-'), number])
            .map((r) => op(r, (a, b) => a - b)),
        number,
      ]);
      var result = expr.parse(scan('10-2-3'));
      expect(result.value, 5);
      expect(result.span?.text, '10-2-3');
      expect(expr.parse(scan('10-x')).value, 10);
    });

    test('two levels give operator precedence', () {
      var expr = reference<int>(), term = reference<int>();
      var factor = any<int>([number, expr.parenthesized()]);
      term.parser = any<int>([
        chain<dynamic>([term, match('*'), factor])
            .map((r) => op(r, (a, b) => a * b)),
        factor,
      ]);
      expr.parser = any<int>([
        chain<dynamic>([expr, match('+'), term])
            .map((r) => op(r, (a, b) => a + b)),
        term,
      ]);
      expect(expr.parse(scan('2+3*4')).value, 14);
      expect(expr.parse(scan('2*3+4')).value, 10);
      expect(expr.parse(scan('(1+2)*3')).value, 9);
    });

    test('works with longest', () {
      var expr = reference<int>();
      expr.parser = longest<int>([
        chain<dynamic>([expr, match('+'), number])
            .map((r) => op(r, (a, b) => a + b)),
        number,
      ]);
      expect(expr.parse(scan('1+2+3')).value, 6);
    });

    test('indirect left recursion', () {
      var a = reference<String>(), b = reference<String>();
      b.parser = a;
      a.parser = any<String>([
        chain<dynamic>([b, match('x')]).map((r) => '${r.value![0]}x'),
        match('y').map((r) => 'y'),
      ]);
      expect(a.parse(scan('yxxx')).value, 'yxxx');
    });

    test('many left-recursive rules at one position stay fast', () {
      var expr = reference<int>();
      expr.parser = longest<int>([
        for (var o in ['+', '-', '*', '/', '%', '^', '&', '|', '**'])
          chain<dynamic>([expr.space(), match(o).space(), expr.space()])
              .map((r) => op(r, (a, b) => a + b)),
        number,
        expr.parenthesized(),
      ]);
      var sw = Stopwatch()..start();
      expect(expr.parse(scan('((((((4))))))')).value, 4);
      expect(expr.parse(scan('1+2+3+4+5+6+7+8+9')).value, 45);
      expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
    });
  });

  group('left recursion with other combinators', () {
    int sum(ParseResult<List> r) => (r.value![0] as int) + (r.value![2] as int);

    test('a cached part of a left-recursive rule still grows', () {
      var expr = reference<int>();
      expr.parser = any<int>([
        chain<dynamic>([expr, match('+'), number]).map(sum).cache(),
        number,
      ]);
      var result = expr.parse(scan('1+2+3'));
      expect(result.value, 6);
      expect(result.span?.text, '1+2+3');
    });

    test('a rule first reached while another grows also grows', () {
      // list := list ',' item | item ; item := item '.' | number
      var list = reference<List<int>>(), item = reference<int>();
      item.parser = any<int>([
        chain<dynamic>([item, match('.')]).map((r) => (r.value![0] as int) + 1),
        number,
      ]);
      list.parser = any<List<int>>([
        chain<dynamic>([list, match(','), item])
            .map((r) => [...r.value![0] as List<int>, r.value![2] as int]),
        item.map((r) => [r.value!]),
      ]);
      expect(list.parse(scan('1..,5,2...')).value, [3, 5, 5]);
    });

    test('long left-recursive input stays fast', () {
      var expr = reference<int>();
      expr.parser = any<int>([
        chain<dynamic>([expr, match('+'), number]).map(sum),
        number,
      ]);
      var input = List.filled(2000, '1').join('+');
      var sw = Stopwatch()..start();
      expect(expr.parse(scan(input)).value, 2000);
      expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
    });
  });

  test('chain with failFast: false fails instead of throwing', () {
    var word = match<String>('a').value((_) => 'a');
    var other = match<String>('b').value((_) => 'b');
    var result = chain<String>([
      word,
      other,
    ], failFast: false).parse(scan('ax'));
    expect(result.successful, isFalse);
    expect(result.value, isNull);
  });

  test('opt(backtrack: false) keeps the consumed text in its span', () {
    var ab = chain([match('a'), match('b')]);
    var p = chain<dynamic>([ab.opt(backtrack: false), match('c')]).flatten();
    expect(p.parse(scan('ac')).value, 'ac');
  });

  test('mutually left-recursive rules growing at the same position', () {
    // a := b 'x' | 'a' ; b := b 'y' | a, so a matches 'a' then groups of y* x.
    var a = reference<String>(), b = reference<String>();
    a.parser = any<String>([
      chain<dynamic>([b, match('x')]).map((r) => '(${r.value![0]}x)'),
      match('a').map((r) => 'a'),
    ]);
    b.parser = any<String>([
      chain<dynamic>([b, match('y')]).map((r) => '[${r.value![0]}y]'),
      a,
    ]);
    for (var input in ['a', 'ax', 'ayx', 'axx', 'axyx', 'ayxyyx']) {
      expect(a.parse(scan(input)).span?.text, input, reason: input);
    }
    expect(a.parse(scan('axyx')).value, '([(ax)y]x)');
  });

  test('chain with failFast: false does not throw after an element failed', () {
    var word = match<String>('a').value((_) => 'a');
    var other = match<String>('b').value((_) => 'b');
    var empty = match<String>('c').opt();
    var result = chain<String>([
      word,
      other,
      empty,
    ], failFast: false).parse(scan('ax'));
    expect(result.successful, isFalse);
    expect(result.value, isNull);
  });

  test('the StateError names the element without a value', () {
    var word = match<String>('a').value((_) => 'a');
    expect(
      () => chain<String>([word, word, match('b')]).parse(scan('aab')),
      throwsA(
        isA<StateError>().having((e) => e.message, 'message', contains('#3')),
      ),
    );
  });

  test('opt gives no span when nothing was consumed', () {
    var ab = chain([match('a'), match('b')]);
    expect(ab.opt().parse(scan('x')).span, isNull);
    expect(ab.opt(backtrack: false).parse(scan('x')).span, isNull);
    expect(ab.opt(backtrack: false).parse(scan('ax')).span?.text, 'a');
  });

  test('cache() returns the parser itself', () {
    expect(identical(number.cache(), number), isTrue);
  });

  test('getMemoized throws a StateError when nothing is memoized', () {
    expect(() => Trampoline().getMemoized(number, 0), throwsStateError);
  });
}
