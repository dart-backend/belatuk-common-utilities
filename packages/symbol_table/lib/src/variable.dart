part of 'symbol_table.dart';

/// Holds a symbol, the value of which may change or be marked immutable.
class Variable<T> {
  final String name;
  final SymbolTable<T>? symbolTable;
  Visibility visibility = Visibility.public;
  bool _locked = false;
  T? _value;

  Variable._(this.name, this.symbolTable, {T? value}) {
    _value = value;
  }

  /// If `true`, then the value of this variable cannot be overwritten.
  bool get isImmutable => _locked;

  T? get value => _value;

  set value(T? value) {
    if (_locked) {
      throw StateError('The value of constant "$name" cannot be overwritten.');
    }
    _value = value;
  }

  /// Locks this symbol, and prevents its [value] from being overwritten.
  void lock() {
    _locked = true;
  }
}
