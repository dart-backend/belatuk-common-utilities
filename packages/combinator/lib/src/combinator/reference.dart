part of 'combinator.dart';

Reference<T> reference<T>() => Reference<T>._();

/// The references already printed into each [CodeBuffer], so each one is printed in full only once.
final Expando<Set<Reference>> _printedReferences = Expando();

class Reference<T> extends Parser<T> {
  Parser<T>? _parser;

  Reference._();

  set parser(Parser<T> value) {
    if (_parser != null) {
      throw StateError('There is already a parser assigned to this reference.');
    }
    _parser = value;
  }

  @override
  ParseResult<T> __parse(ParseArgs args) {
    if (_parser == null) {
      throw StateError('There is no parser assigned to this reference.');
    }
    return _parser!._parse(args);
  }

  @override
  ParseResult<T> _parse(ParseArgs args) {
    if (_parser == null) {
      throw StateError('There is no parser assigned to this reference.');
    }
    return _parser!._parse(args);
  }

  @override
  void stringify(CodeBuffer buffer) {
    var printed = _printedReferences[buffer] ??= {};
    if (_parser == null) {
      buffer.writeln('(undefined reference <$T>)');
    } else if (printed.add(this)) {
      // Marked before printing, so a reference that contains itself does not recurse forever.
      _parser!.stringify(buffer);
    } else {
      buffer.writeln('(previously printed reference)');
    }
  }
}
