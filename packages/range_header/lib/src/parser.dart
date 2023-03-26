import 'package:charcode/charcode.dart';
import 'package:source_span/source_span.dart';
import 'package:string_scanner/string_scanner.dart';
import 'exception.dart';
import 'range_header.dart';
import 'range_header_impl.dart';
import 'range_header_item.dart';

final RegExp _rgxInt = RegExp(r'[0-9]+');
final RegExp _rgxWs = RegExp(r'[ \n\r\t]');

enum TokenType { rangeUnit, comma, int, dash, equals }

class Token {
  final TokenType type;
  final SourceSpan? span;

  Token(this.type, this.span);
}

List<Token> scan(String text, List<String> allowedRangeUnits) {
  var tokens = <Token>[];
  var scanner = SpanScanner(text);

  while (!scanner.isDone) {
    // Skip whitespace
    scanner.scan(_rgxWs);

    if (scanner.scanChar($comma)) {
      tokens.add(Token(TokenType.comma, scanner.lastSpan));
    } else if (scanner.scanChar($dash)) {
      tokens.add(Token(TokenType.dash, scanner.lastSpan));
    } else if (scanner.scan(_rgxInt)) {
      tokens.add(Token(TokenType.int, scanner.lastSpan));
    } else if (scanner.scanChar($equal)) {
      tokens.add(Token(TokenType.equals, scanner.lastSpan));
    } else {
      var matched = false;

      for (var unit in allowedRangeUnits) {
        if (scanner.scan(unit)) {
          tokens.add(Token(TokenType.rangeUnit, scanner.lastSpan));
          matched = true;
          break;
        }
      }

      if (!matched) {
        var ch = scanner.readChar();
        throw RangeHeaderParseException(
            'Unexpected character: "${String.fromCharCode(ch)}"');
      }
    }
  }

  return tokens;
}

class Parser {
  Token? _current;
  int _index = -1;
  final List<Token> tokens;

  Parser(this.tokens);

  Token? get current => _current;

  bool get done => _index >= tokens.length - 1;

  RangeHeaderParseException _expected(String type) {
    var offset = current?.span?.start.offset;

    if (offset == null) return RangeHeaderParseException('Expected $type.');

    Token? peek;

    if (_index < tokens.length - 1) peek = tokens[_index + 1];

    if (peek != null && peek.span != null) {
      return RangeHeaderParseException(
          'Expected $type at offset $offset, found "${peek.span!.text}" instead. \nSource:\n${peek.span?.highlight() ?? peek.type}');
    } else {
      return RangeHeaderParseException(
          'Expected $type at offset $offset, but the header string ended without one.\nSource:\n${current!.span?.highlight() ?? current!.type}');
    }
  }

  bool next(TokenType type) {
    if (done) return false;
    var tok = tokens[_index + 1];
    if (tok.type == type) {
      _index++;
      _current = tok;
      return true;
    } else {
      return false;
    }
  }

  RangeHeader? parseRangeHeader() {
    if (next(TokenType.rangeUnit)) {
      var unit = current!.span!.text;
      next(TokenType.equals); // Consume =, if any.

      var items = <RangeHeaderItem>[];
      var item = parseHeaderItem();

      while (item != null) {
        items.add(item);
        // Parse comma
        if (next(TokenType.comma)) {
          item = parseHeaderItem();
        } else {
          item = null;
        }
      }

      if (items.isEmpty) {
        throw _expected('range');
      } else {
        return RangeHeaderImpl(unit, items);
      }
    } else {
      return null;
    }
  }

  RangeHeaderItem? parseHeaderItem() {
    if (next(TokenType.int)) {
      // i.e 500-544, or 600-
      var start = int.parse(current!.span!.text);
      if (next(TokenType.dash)) {
        if (next(TokenType.int)) {
          return RangeHeaderItem(start, int.parse(current!.span!.text));
        } else {
          return RangeHeaderItem(start);
        }
      } else {
        throw _expected('"-"');
      }
    } else if (next(TokenType.dash)) {
      // i.e. -599
      if (next(TokenType.int)) {
        return RangeHeaderItem(-1, int.parse(current!.span!.text));
      } else {
        throw _expected('integer');
      }
    } else {
      return null;
    }
  }
}
