part of 'combinator.dart';

class _Cache<T> extends Parser<T> {
  /// Each parse's results and end positions, by start position. Keyed by the parse's
  /// [Trampoline], so results never carry over to another parse.
  final Expando<Map<int, (ParseResult<T>, int)>> _cache = Expando();
  final Parser<T> parser;

  _Cache(this.parser);

  @override
  ParseResult<T> __parse(ParseArgs args) {
    var cache = _cache[args.trampoline] ??= {};
    var start = args.scanner.position;
    var cached = cache[start];

    if (cached == null) {
      var result = parser._parse(args.increaseDepth());
      cached = cache[start] = (result, args.scanner.position);
    } else {
      args.scanner.position = cached.$2;
    }

    return cached.$1.change(parser: this);
  }

  @override
  void _stringify(CodeBuffer buffer, _StringifyContext context) {
    buffer
      ..writeln('cache (')
      ..indent();
    parser._stringify(buffer, context);
    buffer
      ..outdent()
      ..writeln(')');
  }
}
