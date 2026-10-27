part of 'combinator.dart';

/// Matches any one of the given [parsers].
///
/// If [backtrack] is `true` (default), a failed parse will not modify the scanner state.
///
/// You can provide a custom [errorMessage]. You can set it to `false` to not
/// generate any error at all.
Parser<T> any<T>(
  Iterable<Parser<T>> parsers, {
  bool backtrack = true,
  errorMessage,
  SyntaxErrorSeverity? severity,
}) {
  return _Any(
    parsers,
    backtrack != false,
    errorMessage,
    severity ?? SyntaxErrorSeverity.error,
  );
}

class _Any<T> extends Parser<T> {
  final Iterable<Parser<T>> parsers;
  final bool backtrack;
  final dynamic errorMessage;
  final SyntaxErrorSeverity severity;

  _Any(this.parsers, this.backtrack, this.errorMessage, this.severity);

  @override
  ParseResult<T> _parse(ParseArgs args) {
    var errors = <SyntaxError>[];
    var replay = args.scanner.position;

    // An alternative that is already being parsed at this position fails in Parser._parse,
    // which also detects the left recursion and grows its result.
    for (var parser in parsers) {
      var result = parser._parse(args.increaseDepth());

      if (result.successful) {
        return result;
      } else {
        if (backtrack) args.scanner.position = replay;
        if (parser is _Alt) errors.addAll(result.errors);
      }
    }

    if (errorMessage != false) {
      errors.add(
        SyntaxError(
          severity,
          errorMessage?.toString() ??
              'No match found for ${parsers.length} alternative(s)',
          args.scanner.emptySpan,
        ),
      );
    }

    return ParseResult(args.trampoline, args.scanner, this, false, errors);
  }

  @override
  ParseResult<T> __parse(ParseArgs args) {
    // Never called
    throw ArgumentError('[Combinator] Invalid method call');
  }

  @override
  void _stringify(CodeBuffer buffer, _StringifyContext context) {
    buffer
      ..writeln('any(${parsers.length}) (')
      ..indent();
    var i = 1;

    for (var parser in parsers) {
      buffer
        ..writeln('#${i++}:')
        ..indent();
      parser._stringify(buffer, context);
      buffer.outdent();
    }

    buffer
      ..outdent()
      ..writeln(')');
  }
}
