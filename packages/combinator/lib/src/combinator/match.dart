part of 'combinator.dart';

/// Expects to match a given [pattern]. If it is not matched, you can provide a custom [errorMessage].
Parser<T> match<T>(Pattern pattern,
        {String? errorMessage, SyntaxErrorSeverity? severity}) =>
    _Match<T>(pattern, errorMessage, severity ?? SyntaxErrorSeverity.error);

class _Match<T> extends Parser<T> {
  final Pattern pattern;
  final String? errorMessage;
  final SyntaxErrorSeverity severity;

  _Match(this.pattern, this.errorMessage, this.severity);

  @override
  ParseResult<T> __parse(ParseArgs args) {
    var scanner = args.scanner;
    if (!scanner.scan(pattern)) {
      return ParseResult(args.trampoline, scanner, this, false, [
        SyntaxError(
          severity,
          errorMessage ?? 'Expected "$pattern".',
          scanner.emptySpan,
        ),
      ]);
    }
    return ParseResult<T>(
      args.trampoline,
      scanner,
      this,
      true,
      [],
      span: scanner.lastSpan,
    );
  }

  @override
  void stringify(CodeBuffer buffer) {
    buffer.writeln('match($pattern)');
  }
}
