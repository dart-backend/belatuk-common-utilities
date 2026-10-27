part of 'combinator.dart';

class _Opt<T> extends Parser<T> {
  final Parser<T> parser;
  final bool backtrack;

  _Opt(this.parser, this.backtrack);

  @override
  ParseResult<T> __parse(ParseArgs args) {
    var replay = args.scanner.position;
    var result = parser._parse(args.increaseDepth());

    if (!result.successful && backtrack) args.scanner.position = replay;

    return result.change(parser: this, successful: true);
  }

  @override
  void _stringify(CodeBuffer buffer, _StringifyContext context) {
    buffer
      ..writeln('optional (')
      ..indent();
    parser._stringify(buffer, context);
    buffer
      ..outdent()
      ..writeln(')');
  }
}

class _ListOpt<T> extends ListParser<T> {
  final ListParser<T> parser;
  final bool backtrack;

  /// Whether a failed parse produces an empty list, instead of no value.
  final bool emptyOnFailure;

  _ListOpt(this.parser, this.backtrack, {this.emptyOnFailure = false});

  @override
  ParseResult<List<T>> __parse(ParseArgs args) {
    var replay = args.scanner.position;
    var result = parser._parse(args.increaseDepth());

    if (!result.successful && backtrack) args.scanner.position = replay;

    return result.change(
      parser: this,
      successful: true,
      value: emptyOnFailure ? (result.value ?? <T>[]) : null,
    );
  }

  @override
  void _stringify(CodeBuffer buffer, _StringifyContext context) {
    buffer
      ..writeln('optional (')
      ..indent();
    parser._stringify(buffer, context);
    buffer
      ..outdent()
      ..writeln(')');
  }
}
