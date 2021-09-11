part of lex.src.combinator;

/// Matches any one of the given [parsers].
///
/// You can provide a custom [errorMessage].
Parser<T> longest<T>(Iterable<Parser<T>> parsers,
    {Object? errorMessage, SyntaxErrorSeverity? severity}) {
  return _Longest(parsers, errorMessage, severity ?? SyntaxErrorSeverity.error);
}

class _Longest<T> extends Parser<T> {
  final Iterable<Parser<T>> parsers;
  final Object? errorMessage;
  final SyntaxErrorSeverity severity;

  _Longest(this.parsers, this.errorMessage, this.severity);

  @override
  ParseResult<T> _parse(ParseArgs args) {
    var inactive = parsers
        .toList()
        .where((p) => !args.trampoline.isActive(p, args.scanner.position));

    if (inactive.isEmpty) {
      return ParseResult(args.trampoline, args.scanner, this, false, []);
    }

    var replay = args.scanner.position;
    var errors = <SyntaxError>[];
    var results = <ParseResult<T>>[];

    for (var parser in inactive) {
      var result = parser._parse(args.increaseDepth());

      if (result.successful && result.span != null) {
        results.add(result);
      } else if (parser is _Alt) errors.addAll(result.errors);

      args.scanner.position = replay;
    }

    if (results.isNotEmpty) {
      results.sort((a, b) => b.span!.length.compareTo(a.span!.length));
      args.scanner.scan(results.first.span!.text);
      return results.first;
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
    var replay = args.scanner.position;
    var errors = <SyntaxError>[];
    var results = <ParseResult<T>>[];

    for (var parser in parsers) {
      var result = parser._parse(args.increaseDepth());

      if (result.successful) {
        results.add(result);
      } else if (parser is _Alt) errors.addAll(result.errors);

      args.scanner.position = replay;
    }

    if (results.isNotEmpty) {
      results.sort((a, b) => b.span!.length.compareTo(a.span!.length));
      args.scanner.scan(results.first.span!.text);
      return results.first;
    }

    errors.add(
      SyntaxError(
        severity,
        errorMessage?.toString() ??
            'No match found for ${parsers.length} alternative(s)',
        args.scanner.emptySpan,
      ),
    );

    return ParseResult(args.trampoline, args.scanner, this, false, errors);
  }

  @override
  void stringify(CodeBuffer buffer) {
    buffer
      ..writeln('longest(${parsers.length}) (')
      ..indent();
    var i = 1;

    for (var parser in parsers) {
      buffer
        ..writeln('#${i++}:')
        ..indent();
      parser.stringify(buffer);
      buffer.outdent();
    }

    buffer
      ..outdent()
      ..writeln(')');
  }
}
