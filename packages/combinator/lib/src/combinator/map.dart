part of 'combinator.dart';

class _Map<T, U> extends Parser<U> {
  final Parser<T> parser;
  final U Function(ParseResult<T>) f;

  _Map(this.parser, this.f);

  @override
  ParseResult<U> __parse(ParseArgs args) {
    var result = parser._parse(args.increaseDepth());
    return ParseResult<U>(
      args.trampoline,
      args.scanner,
      this,
      result.successful,
      result.errors,
      span: result.span,
      value: result.successful ? f(result) : null,
    );
  }

  @override
  void _stringify(CodeBuffer buffer, _StringifyContext context) {
    buffer
      ..writeln('map<$U> (')
      ..indent();
    parser._stringify(buffer, context);
    buffer
      ..outdent()
      ..writeln(')');
  }
}

class _Change<T, U> extends Parser<U> {
  final Parser<T> parser;
  final ParseResult<U> Function(ParseResult<T>) f;

  _Change(this.parser, this.f);

  @override
  ParseResult<U> __parse(ParseArgs args) {
    return f(parser._parse(args.increaseDepth())).change(parser: this);
  }

  @override
  void _stringify(CodeBuffer buffer, _StringifyContext context) {
    buffer
      ..writeln('change($f) (')
      ..indent();
    parser._stringify(buffer, context);
    buffer
      ..outdent()
      ..writeln(')');
  }
}
