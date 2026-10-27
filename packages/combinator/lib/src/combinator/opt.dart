part of 'combinator.dart';

/// The span of the text a failed attempt consumed from [start], or `null` if it consumed none.
FileSpan? _consumedSpan(SpanScanner scanner, LineScannerState start) =>
    scanner.position == start.position ? null : scanner.spanFrom(start);

class _Opt<T> extends Parser<T> {
  final Parser<T> parser;
  final bool backtrack;

  _Opt(this.parser, this.backtrack);

  @override
  ParseResult<T> __parse(ParseArgs args) {
    var start = args.scanner.state;
    var result = parser._parse(args.increaseDepth());

    if (!result.successful) {
      if (backtrack) args.scanner.state = start;
      return ParseResult<T>(
        args.trampoline,
        args.scanner,
        this,
        true,
        result.errors,
        span: backtrack ? null : _consumedSpan(args.scanner, start),
      );
    }

    return result.change(parser: this);
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
    var start = args.scanner.state;
    var result = parser._parse(args.increaseDepth());

    if (!result.successful) {
      if (backtrack) args.scanner.state = start;
      return ParseResult<List<T>>(
        args.trampoline,
        args.scanner,
        this,
        true,
        result.errors,
        span: backtrack ? null : _consumedSpan(args.scanner, start),
        value: emptyOnFailure ? <T>[] : null,
      );
    }

    return result.change(parser: this);
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
