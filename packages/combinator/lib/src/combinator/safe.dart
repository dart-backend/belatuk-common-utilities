part of lex.src.combinator;

class _Safe<T> extends Parser<T> {
  final Parser<T> parser;
  final bool backtrack;
  final String errorMessage;
  final SyntaxErrorSeverity severity;
  bool _triggered = false;

  _Safe(this.parser, this.backtrack, this.errorMessage, this.severity);

  @override
  ParseResult<T> __parse(ParseArgs args) {
    var replay = args.scanner.position;

    try {
      if (_triggered) throw Exception();
      return parser._parse(args.increaseDepth());
    } catch (_) {
      _triggered = true;
      if (backtrack) args.scanner.position = replay;
      var errors = <SyntaxError>[];

      errors.add(
        SyntaxError(
          severity,
          errorMessage,
          args.scanner.lastSpan ?? args.scanner.emptySpan,
        ),
      );

      return ParseResult<T>(args.trampoline, args.scanner, this, false, errors);
    }
  }

  @override
  void stringify(CodeBuffer buffer) {
    var t = _triggered ? 'triggered' : 'not triggered';
    buffer
      ..writeln('safe($t) (')
      ..indent();
    parser.stringify(buffer);
    buffer
      ..outdent()
      ..writeln(')');
  }
}
