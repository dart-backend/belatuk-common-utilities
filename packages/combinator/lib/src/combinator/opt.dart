part of 'combinator.dart';

/// Parses [parser] on behalf of the optional parser [self], so that a failed attempt
/// still succeeds, with [fallback] as its value.
///
/// If [backtrack] is `true`, a failed attempt restores the scanner. Otherwise it keeps
/// the text the attempt consumed, and covers it with its span.
ParseResult<U> _parseOptional<U>(
  Parser<U> self,
  Parser<U> parser,
  bool backtrack,
  ParseArgs args, {
  U? fallback,
}) {
  var scanner = args.scanner;
  var start = scanner.state;
  var result = parser._parse(args.increaseDepth());

  if (result.successful) return result.change(parser: self);

  if (backtrack) scanner.state = start;
  var consumed = !backtrack && scanner.position != start.position;
  return ParseResult<U>(
    args.trampoline,
    scanner,
    self,
    true,
    result.errors,
    span: consumed ? scanner.spanFrom(start) : null,
    value: fallback,
  );
}

class _Opt<T> extends Parser<T> {
  final Parser<T> parser;
  final bool backtrack;

  _Opt(this.parser, this.backtrack);

  @override
  ParseResult<T> __parse(ParseArgs args) =>
      _parseOptional(this, parser, backtrack, args);

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
  ParseResult<List<T>> __parse(ParseArgs args) => _parseOptional(
    this,
    parser,
    backtrack,
    args,
    fallback: emptyOnFailure ? <T>[] : null,
  );

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
