part of 'combinator.dart';

Reference<T> reference<T>() => Reference<T>._();

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
  void _stringify(CodeBuffer buffer, _StringifyContext context) {
    if (_parser == null) {
      buffer.writeln('(undefined reference <$T>)');
      return;
    }

    var id = context.referenceIds[this];
    if (id != null) {
      buffer.writeln('reference #$id (printed above)');
      return;
    }

    // Numbered before printing, so a reference that contains itself does not recurse forever.
    id = context.referenceIds[this] = context.referenceIds.length + 1;
    buffer
      ..writeln('reference #$id (')
      ..indent();
    _parser!._stringify(buffer, context);
    buffer
      ..outdent()
      ..writeln(')');
  }
}
