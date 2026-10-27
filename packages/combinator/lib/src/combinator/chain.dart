part of 'combinator.dart';

/// Expects to parse a sequence of [parsers].
///
/// If [failFast] is `true` (default), then the first failure to parse will abort the parse.
///
/// The value has one element per parser, in order. An element is `null` when its parser
/// produced no value, as an optional parser can, so use a nullable [T], such as `int?`,
/// when that can happen. A non-nullable [T] then throws a [StateError].
ListParser<T> chain<T>(
  Iterable<Parser<T>> parsers, {
  bool failFast = true,
  SyntaxErrorSeverity? severity,
}) {
  return _Chain<T>(
    parsers,
    failFast != false,
    severity ?? SyntaxErrorSeverity.error,
  );
}

class _Alt<T> extends Parser<T> {
  final Parser<T> parser;
  final String? errorMessage;
  final SyntaxErrorSeverity severity;

  _Alt(this.parser, this.errorMessage, this.severity);

  @override
  ParseResult<T> __parse(ParseArgs args) {
    var result = parser._parse(args.increaseDepth());
    return result.successful
        ? result
        : result.addErrors([
            SyntaxError(
              severity,
              errorMessage,
              result.span ?? args.scanner.emptySpan,
            ),
          ]);
  }

  @override
  void _stringify(CodeBuffer buffer, _StringifyContext context) {
    parser._stringify(buffer, context);
  }
}

class _Chain<T> extends ListParser<T> {
  final Iterable<Parser<T>> parsers;
  final bool failFast;
  final SyntaxErrorSeverity severity;

  _Chain(this.parsers, this.failFast, this.severity);

  @override
  ParseResult<List<T>> __parse(ParseArgs args) {
    var errors = <SyntaxError>[];
    var results = <T>[];
    var spans = <FileSpan>[];
    var successful = true;

    // False once a failed element leaves no value that fits [T]. The chain has failed
    // then, so it gives no value instead of a list with a gap.
    var complete = true;

    var element = 0;

    for (var parser in parsers) {
      element++;
      var result = parser._parse(args.increaseDepth());

      if (!result.successful) {
        if (parser is _Alt) errors.addAll(result.errors);

        if (failFast) {
          return ParseResult(
            args.trampoline,
            args.scanner,
            this,
            false,
            result.errors,
          );
        }

        successful = false;
      }

      var value = result.value;
      if (value is T) {
        results.add(value);
      } else if (value == null && null is T) {
        results.add(null as T);
      } else if (!successful) {
        // The chain has already failed, so a missing value is not an error.
        complete = false;
      } else {
        throw StateError(
          'Element #$element of chain<$T> produced no value. '
          'Use a nullable type, such as chain<$T?>, when an element can be empty.',
        );
      }

      if (result.span != null) {
        spans.add(result.span!);
      }
    }

    FileSpan? span;

    if (spans.isNotEmpty) {
      span = spans.reduce((a, b) => a.expand(b));
    }

    return ParseResult<List<T>>(
      args.trampoline,
      args.scanner,
      this,
      successful,
      errors,
      span: span,
      value: complete ? List<T>.unmodifiable(results) : null,
    );
  }

  @override
  void _stringify(CodeBuffer buffer, _StringifyContext context) {
    buffer
      ..writeln('chain(${parsers.length}) (')
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
