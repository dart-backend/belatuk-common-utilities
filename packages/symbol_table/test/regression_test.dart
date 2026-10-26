import 'package:belatuk_symbol_table/belatuk_symbol_table.dart';
import 'package:test/test.dart';

void main() {
  late SymbolTable<int> scope;

  setUp(() {
    scope = SymbolTable<int>(values: {'one': 1});
  });

  group('fork', () {
    test('uses its starter values', () {
      var fork = scope.fork(values: {'x': 1, 'one': 10});
      expect(fork.resolve('x')!.value, 1);
      expect(fork.resolve('one')!.value, 10);
      expect(scope.resolve('one')!.value, 1);
    });

    test('variables belong to the fork', () {
      var fork = scope.fork();
      expect(fork.resolve('one')!.symbolTable, same(fork));
    });

    test('does not return a variable removed from an ancestor', () {
      scope.create('x');
      var fork = scope.createChild().fork();
      expect(fork.resolve('x'), isNotNull);
      scope.remove('x');
      expect(fork.resolve('x'), isNull);
    });

    test('sees a variable that newly shadows an ancestor', () {
      var child = scope.createChild();
      var fork = child.createChild().fork();
      expect(fork.resolve('one')!.value, 1);
      child.create('one', value: 2);
      expect(fork.resolve('one')!.value, 2);
    });

    test('keeps the context', () {
      var child = scope.createChild()..context = 24;
      expect(child.fork().context, 24);
    });

    test('does not repeat unique names', () {
      expect(scope.uniqueName('t'), 't0');
      expect(scope.fork().uniqueName('t'), 't1');
    });
  });

  group('clone', () {
    test('copies variables', () {
      var clone = scope.clone();
      clone.assign('one', 99);
      expect(scope.resolve('one')!.value, 1);
      expect(clone.resolve('one')!.value, 99);
      expect(clone.resolve('one')!.symbolTable, same(clone));
    });

    test('keeps constants and visibility', () {
      scope.resolve('one')!
        ..lock()
        ..visibility = Visibility.private;
      var copy = scope.clone().resolve('one')!;
      expect(copy.isImmutable, isTrue);
      expect(copy.visibility, Visibility.private);
    });

    test('keeps the context', () {
      var child = scope.createChild()..context = 24;
      expect(child.clone().context, 24);
    });
  });

  test('allPublicVariables leaves out shadowed variables', () {
    var child = scope.createChild();
    child.create('one').visibility = Visibility.private;
    expect(child.allPublicVariables, isEmpty);
    expect(child.allVariables.single.symbolTable, same(child));
  });

  group('uniqueName', () {
    test('an ancestor does not repeat a descendant name', () {
      var child = scope.createChild();
      expect(child.uniqueName('foo'), 'foo0');
      expect(scope.uniqueName('foo'), 'foo1');
    });

    test('skips names of visible variables', () {
      scope.create('foo0');
      expect(scope.createChild().uniqueName('foo'), 'foo1');
    });
  });
}
