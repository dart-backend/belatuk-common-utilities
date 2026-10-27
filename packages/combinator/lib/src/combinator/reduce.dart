part of 'combinator.dart';

class _Reduce<T> extends Parser<T> {
  final ListParser<T> parser;
  final T Function(T, T) combine;

  _Reduce(this.parser, this.combine);

  @override
  ParseResult<T> __parse(ParseArgs args) {
    var result = parser._parse(args.increaseDepth());

    if (!result.successful) {
      return ParseResult<T>(
        args.trampoline,
        args.scanner,
        this,
        false,
        result.errors,
      );
    }

    result = result.change(
      value: result.value?.isNotEmpty == true ? result.value : [],
    );
    return ParseResult<T>(
      args.trampoline,
      args.scanner,
      this,
      result.successful,
      [],
      span: result.span,
      value: result.value!.isEmpty ? null : result.value!.reduce(combine),
    );
  }

  @override
  void _stringify(CodeBuffer buffer, _StringifyContext context) {
    buffer
      ..writeln('reduce($combine) (')
      ..indent();
    parser._stringify(buffer, context);
    buffer
      ..outdent()
      ..writeln(')');
  }
}
