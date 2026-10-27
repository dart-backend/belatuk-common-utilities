library;

import 'dart:collection';

import 'package:belatuk_code_buffer/belatuk_code_buffer.dart';
import 'package:matcher/matcher.dart';
import 'package:source_span/source_span.dart';
import 'package:string_scanner/string_scanner.dart';
import 'package:tuple/tuple.dart';

import '../error.dart';

part 'any.dart';

part 'advance.dart';

part 'cast.dart';

part 'chain.dart';

part 'check.dart';

part 'compare.dart';

part 'fold_errors.dart';

part 'index.dart';

part 'longest.dart';

part 'map.dart';

part 'match.dart';

part 'max_depth.dart';

part 'negate.dart';

part 'opt.dart';

part 'recursion.dart';

part 'reduce.dart';

part 'reference.dart';

part 'repeat.dart';

part 'safe.dart';

part 'to_list.dart';

part 'util.dart';

part 'value.dart';

class ParseArgs {
  final Trampoline trampoline;
  final SpanScanner scanner;
  final int depth;

  ParseArgs(this.trampoline, this.scanner, this.depth);

  ParseArgs increaseDepth() => ParseArgs(trampoline, scanner, depth + 1);
}

/// A parser combinator, which can parse very complicated grammars in a manageable manner.
abstract class Parser<T> {
  ParseResult<T> __parse(ParseArgs args);

  ParseResult<T> _parse(ParseArgs args) {
    var trampoline = args.trampoline;
    var pos = args.scanner.position;

    var memoized = trampoline._entry(this, pos);
    if (memoized != null) {
      // Move the scanner to where the memoized parse ended, as the original parse did.
      var (result, end) = memoized;
      if (end != null) args.scanner.position = end;
      return result as ParseResult<T>;
    }

    if (trampoline.isActive(this, pos)) {
      // Left recursion: this parser was entered again without consuming any text.
      // Fail for now, and grow the result once the outer parse finishes.
      trampoline._leftRecursive.add((this, pos));
      return ParseResult(trampoline, args.scanner, this, false, []);
    }

    trampoline.enter(this, pos);
    var result = __parse(args);
    var end = args.scanner.position;

    // A failed result has nothing to grow, and leaves the memoized results intact.
    if (trampoline._leftRecursive.remove((this, pos)) && result.successful) {
      // Grow the seed (Warth et al.): parse again with the last result memoized, so the
      // recursive call reuses it, for as long as each pass matches more text. While it
      // grows, clearing the position keeps its seed for any rule nested inside it.
      trampoline._growing.add((this, pos));
      while (result.successful) {
        trampoline._forgetAt(pos);
        trampoline._remember(this, pos, result, end);
        args.scanner.position = pos;
        var next = __parse(args);
        var nextEnd = args.scanner.position;
        if (!next.successful || nextEnd <= end) break;
        result = next;
        end = nextEnd;
      }

      trampoline._growing.remove((this, pos));
      // A nested rule may have marked this parser again during growth. It has finished.
      trampoline._leftRecursive.remove((this, pos));

      // Results memoized at this position during growth may depend on an older seed.
      trampoline._forgetAt(pos);
      args.scanner.position = end;
    }

    trampoline._remember(this, pos, result, end);
    trampoline.exit(this);
    return result;
  }

  /// Parses text from a [SpanScanner].
  ParseResult<T> parse(SpanScanner scanner, [int depth = 1]) {
    var args = ParseArgs(Trampoline(), scanner, depth);
    return _parse(args);
  }

  /// Skips forward a certain amount of steps after parsing, if it was successful.
  Parser<T> forward(int amount) => _Advance<T>(this, amount);

  /// Moves backward a certain amount of steps after parsing, if it was successful.
  Parser<T> back(int amount) => _Advance<T>(this, amount * -1);

  /// Casts this parser to produce [U] objects.
  Parser<U> cast<U extends T>() => _Cast<T, U>(this);

  /// Casts this parser to produce [dynamic] objects.
  Parser<dynamic> castDynamic() => _CastDynamic<T>(this);

  /// Runs the given function, which changes the returned [ParseResult] into one relating to a [U] object.
  Parser<U> change<U>(ParseResult<U> Function(ParseResult<T>) f) {
    return _Change<T, U>(this, f);
  }

  /// Validates the parse result against a [Matcher].
  ///
  /// You can provide a custom [errorMessage].
  Parser<T> check(
    Matcher matcher, {
    String? errorMessage,
    SyntaxErrorSeverity? severity,
  }) => _Check<T>(
    this,
    matcher,
    errorMessage,
    severity ?? SyntaxErrorSeverity.error,
  );

  /// Binds an [errorMessage] to a copy of this parser.
  Parser<T> error({String? errorMessage, SyntaxErrorSeverity? severity}) =>
      _Alt<T>(this, errorMessage, severity ?? SyntaxErrorSeverity.error);

  /// Removes multiple errors that occur in the same spot; this can reduce noise in parser output.
  Parser<T> foldErrors({bool Function(SyntaxError a, SyntaxError b)? equal}) {
    equal ??= (b, e) => b.span?.start.offset == e.span?.start.offset;
    return _FoldErrors<T>(this, equal);
  }

  /// Transforms the parse result using a unary function.
  Parser<U> map<U>(U Function(ParseResult<T>) f) {
    return _Map<T, U>(this, f);
  }

  /// Prevents recursion past a certain [depth], preventing stack overflow errors.
  Parser<T> maxDepth(int depth) => _MaxDepth<T>(this, depth);

  Parser<T> operator ~() => negate();

  /// Ensures this pattern is not matched.
  ///
  /// You can provide an [errorMessage].
  Parser<T> negate({
    String errorMessage = 'Negate error',
    SyntaxErrorSeverity severity = SyntaxErrorSeverity.error,
  }) => _Negate<T>(this, errorMessage, severity);

  /// Returns this parser.
  ///
  /// Every parser's results are already cached at each position for the length of one
  /// parse, so this has no effect. It is kept so that existing grammars still compile.
  Parser<T> cache() => this;

  /// Shortcut for [and]. [other] can produce any type of value.
  Parser<T> operator &(Parser other) => and(other);

  /// Consumes `this` and another parser, but only considers the result of `this` parser.
  Parser<T> and(Parser other) => then(other).change<T>((r) {
    return ParseResult<T>(
      r.trampoline,
      r.scanner,
      this,
      r.successful,
      r.errors,
      span: r.span,
      value: (r.value != null ? r.value![0] : r.value) as T?,
    );
  });

  /// Shortcut for [or].
  Parser<T> operator |(Parser other) => or(other);

  /// Matches either this parser or [other], trying this one first.
  ///
  /// If [other] is not a `Parser<T>`, its values are cast to [T], and a value that is
  /// not a [T] throws a [TypeError] when parsed.
  Parser<T> or<U>(Parser other) => any<T>([
    this,
    other is Parser<T> ? other : other.castDynamic().cast<T>(),
  ]);

  /// Parses this sequence one or more times.
  ListParser<T> plus() => times(1, exact: false);

  /// Safely escapes this parser when an error occurs.
  ///
  /// The generated parser only runs once; repeated uses always exit eagerly.
  Parser<T> safe({
    bool backtrack = true,
    String errorMessage = 'error',
    SyntaxErrorSeverity? severity,
  }) => _Safe<T>(
    this,
    backtrack,
    errorMessage,
    severity ?? SyntaxErrorSeverity.error,
  );

  Parser<List<T>> separatedByComma() => separatedBy(match<String>(',').space());

  /// Expects to see an infinite amounts of the pattern, separated by the [other] pattern.
  ///
  /// Use this as a shortcut to parse arrays, parameter lists, etc.
  Parser<List<T>> separatedBy(Parser other) {
    var suffix = other.then(this).index(1).cast<T>();
    return then(suffix.star()).map((r) {
      var v = r.value;
      if (v == null || v.length < 2) {
        return [];
      }
      var preceding = v.isEmpty ? [] : (v[0] == null ? [] : [v[0]]);
      var out = List<T>.from(preceding);
      if (v[1] != null) {
        v[1].forEach((element) {
          out.add(element as T);
        });
      }
      return out;
    });
  }

  Parser<T> surroundedByCurlyBraces({required T defaultValue}) => opt()
      .surroundedBy(match('{').space(), match('}').space())
      .map((r) => r.value ?? defaultValue);

  Parser<T> surroundedBySquareBrackets({required T defaultValue}) => opt()
      .surroundedBy(match('[').space(), match(']').space())
      .map((r) => r.value ?? defaultValue);

  /// Expects to see the pattern, surrounded by the others.
  ///
  /// If no [right] is provided, it expects to see the same pattern on both sides.
  /// Use this parse things like parenthesized expressions, arrays, etc.
  Parser<T> surroundedBy(Parser left, [Parser? right]) {
    return chain([left, this, right ?? left]).index(1).castDynamic().cast<T>();
  }

  /// Parses `this`, either as-is or wrapped in parentheses.
  Parser<T> maybeParenthesized() {
    return any([parenthesized(), this]);
  }

  /// Parses `this`, wrapped in parentheses.
  Parser<T> parenthesized() =>
      surroundedBy(match('(').space(), match(')').space());

  /// Consumes any trailing whitespace.
  Parser<T> space() => trail(RegExp(r'[ \n\r\t]+'));

  /// Consumes 0 or more instance(s) of this parser.
  ///
  /// The value is an empty list when there are none.
  ListParser<T> star({bool backtrack = true}) => _ListOpt(
    times(1, exact: false, backtrack: backtrack),
    true,
    emptyOnFailure: true,
  );

  /// Shortcut for [chain]-ing two parsers together.
  ListParser<dynamic> then(Parser other) => chain<dynamic>([this, other]);

  /// Casts this instance into a [ListParser].
  ListParser<T> toList() => _ToList<T>(this);

  /// Consumes and ignores any trailing occurrences of [pattern].
  Parser<T> trail(Pattern pattern) =>
      then(match(pattern).opt()).first().cast<T>();

  /// Expect this pattern a certain number of times.
  ///
  /// If [exact] is `false` (default: `true`), then the generated parser will accept
  /// an infinite amount of occurrences after the specified [count].
  ///
  /// You can provide custom error messages for when there are [tooFew] or [tooMany] occurrences.
  ListParser<T> times(
    int count, {
    bool exact = true,
    String tooFew = 'Too few',
    String tooMany = 'Too many',
    bool backtrack = true,
    SyntaxErrorSeverity? severity,
  }) {
    return _Repeat<T>(
      this,
      count,
      exact,
      tooFew,
      tooMany,
      backtrack,
      severity ?? SyntaxErrorSeverity.error,
    );
  }

  /// Produces an optional copy of this parser.
  ///
  /// If [backtrack] is `true` (default), then a failed parse will not
  /// modify the scanner state.
  Parser<T> opt({bool backtrack = true}) => _Opt(this, backtrack);

  /// Sets the value of the [ParseResult].
  Parser<T> value(T Function(ParseResult<T?>) f) {
    return _Value<T>(this, f);
  }

  /// Prints a representation of this parser into [buffer].
  ///
  /// Each [Reference] is printed in full the first time it appears in this call, numbered,
  /// and by its number after that, so recursive grammars do not overflow the stack.
  void stringify(CodeBuffer buffer) => _stringify(buffer, _StringifyContext());

  void _stringify(CodeBuffer buffer, _StringifyContext context);
}

/// The state of one [Parser.stringify] call.
class _StringifyContext {
  /// The number of each [Reference] printed so far.
  final Map<Reference, int> referenceIds = {};
}

/// A [Parser] that produces [List]s of a type [T].
abstract class ListParser<T> extends Parser<List<T>> {
  /// Shortcut for calling [index] with `0`.
  Parser<T> first() => index(0);

  /// Modifies this parser to only return the value at the given index [i].
  Parser<T> index(int i) => _Index<T>(this, i);

  /// Shortcut for calling [index] with the greatest-possible index.
  Parser<T> last() => index(-1);

  /// Modifies this parser to call `List.reduce` on the parsed values.
  Parser<T> reduce(T Function(T, T) combine) => _Reduce<T>(this, combine);

  /// Sorts the parsed values, using the given [Comparator].
  ListParser<T> sort(Comparator<T> compare) => _Compare(this, compare);

  @override
  ListParser<T> opt({bool backtrack = true}) => _ListOpt(this, backtrack);

  /// Modifies this parser, returning only the values that match a predicate.
  Parser<List<T>> where(bool Function(T) f) =>
      map<List<T>>((r) => r.value?.where(f).toList() ?? []);

  /// Condenses a [ListParser] into having a value of the combined span's text.
  Parser<String> flatten() => map<String>((r) => r.span?.text ?? '');
}

/// Prevents stack overflow in recursive parsers.
class Trampoline {
  final Map<Parser, Queue<int>> _active = {};

  /// Each memoized result, and where the scanner was after it if known, by start
  /// position and then by parser, so forgetting a position is a single removal.
  final Map<int, Map<Parser, (ParseResult, int?)>> _memo = {};

  /// The parsers that were entered again at the same position while being parsed.
  final Set<(Parser, int)> _leftRecursive = {};

  /// The left-recursive parsers growing their results, with their positions.
  final Set<(Parser, int)> _growing = {};

  (ParseResult, int?)? _entry(Parser parser, int position) =>
      _memo[position]?[parser];

  void _remember(Parser parser, int position, ParseResult result, int end) {
    _memo.putIfAbsent(position, () => {})[parser] = (result, end);
  }

  /// Forgets the results memoized at [position], except the seeds of parsers growing there.
  void _forgetAt(int position) {
    var entries = _memo[position];
    if (entries == null) return;
    entries.removeWhere((parser, _) => !_growing.contains((parser, position)));
    if (entries.isEmpty) _memo.remove(position);
  }

  bool hasMemoized(Parser parser, int position) =>
      _entry(parser, position) != null;

  /// The result memoized for [parser] at [position]. Throws a [StateError] if there is none.
  ParseResult<T> getMemoized<T>(Parser parser, int position) {
    var entry = _entry(parser, position);
    if (entry == null) {
      throw StateError('No result is memoized for $parser at $position.');
    }
    return entry.$1 as ParseResult<T>;
  }

  /// Memoizes [result], unless a result is already memoized for [parser] at [position].
  void memoize(Parser parser, int position, ParseResult? result) {
    if (result != null) {
      _memo
          .putIfAbsent(position, () => {})
          .putIfAbsent(parser, () => (result, null));
    }
  }

  bool isActive(Parser parser, int position) {
    if (!_active.containsKey(parser)) {
      return false;
    }
    var q = _active[parser]!;
    if (q.isEmpty) return false;
    //return q.contains(position);
    return q.first == position;
  }

  void enter(Parser parser, int position) {
    _active.putIfAbsent(parser, () => Queue()).addFirst(position);
  }

  void exit(Parser parser) {
    if (_active.containsKey(parser)) _active[parser]?.removeFirst();
  }
}

/// The result generated by a [Parser].
class ParseResult<T> {
  final Parser<T> parser;
  final bool successful;
  final Iterable<SyntaxError> errors;
  final FileSpan? span;
  final T? value;
  final SpanScanner scanner;
  final Trampoline trampoline;

  ParseResult(
    this.trampoline,
    this.scanner,
    this.parser,
    this.successful,
    this.errors, {
    this.span,
    this.value,
  });

  ParseResult<T> change({
    Parser<T>? parser,
    bool? successful,
    Iterable<SyntaxError> errors = const [],
    FileSpan? span,
    T? value,
  }) {
    return ParseResult<T>(
      trampoline,
      scanner,
      parser ?? this.parser,
      successful ?? this.successful,
      errors.isNotEmpty ? errors : this.errors,
      span: span ?? this.span,
      value: value ?? this.value,
    );
  }

  ParseResult<T> addErrors(Iterable<SyntaxError> errors) {
    return change(errors: List<SyntaxError>.from(this.errors)..addAll(errors));
  }
}
