import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:charcode/ascii.dart';

import 'range_header.dart';

/// A [StreamTransformer] that uses a parsed [RangeHeader] and transforms an input stream
/// into one compatible with the `multipart/byte-ranges` specification.
///
/// Ranges are written in order of their position in the input, and overlapping ranges are
/// merged, as RFC 7233 allows, so the input is only read once. Ranges that start past the
/// end of the input are left out, and ranges that end past it are cut back to its last byte.
class RangeHeaderTransformer
    extends StreamTransformerBase<List<int>, List<int>> {
  final RangeHeader header;
  final String boundary, mimeType;
  final int totalLength;

  /// The first and last index of each part to write, sorted and without overlaps.
  late final List<(int, int)> _parts = _computeParts();

  /// Throws an [ArgumentError] if [header] has no ranges, or none of them can be
  /// satisfied by an input of [totalLength] bytes. In that case, respond with
  /// `416 Range Not Satisfiable` instead.
  RangeHeaderTransformer(
    this.header,
    this.mimeType,
    this.totalLength, {
    String? boundary,
  }) : boundary = boundary ?? _randomString() {
    if (header.items.isEmpty) {
      throw ArgumentError('`header` cannot be null or empty.');
    }
    if (_parts.isEmpty) {
      throw ArgumentError(
        'None of the ranges in `header` can be satisfied by $totalLength bytes.',
      );
    }
  }

  List<(int, int)> _computeParts() {
    var parts = <(int, int)>[];

    for (var item in header.items) {
      var first = item.start == -1
          ? max(0, totalLength - item.end)
          : item.start;
      var last = item.start == -1 || item.end == -1
          ? totalLength - 1
          : min(item.end, totalLength - 1);
      if (first <= last) parts.add((first, last));
    }

    parts.sort((a, b) => a.$1.compareTo(b.$1));

    var merged = <(int, int)>[];
    for (var part in parts) {
      if (merged.isNotEmpty && part.$1 <= merged.last.$2) {
        merged.last = (merged.last.$1, max(merged.last.$2, part.$2));
      } else {
        merged.add(part);
      }
    }

    return merged;
  }

  List<int> _partHeader((int, int) part) => utf8.encode(
    '--$boundary\r\n'
    'Content-Type: $mimeType\r\n'
    'Content-Range: ${header.rangeUnit} ${part.$1}-${part.$2}/$totalLength\r\n\r\n',
  );

  List<int> get _closingBoundary => utf8.encode('--$boundary--\r\n');

  /// Computes the content length that will be written to a response.
  ///
  /// [totalFileSize] is optional, and must equal [totalLength] if given.
  int computeContentLength([int? totalFileSize]) {
    if (totalFileSize != null && totalFileSize != totalLength) {
      throw ArgumentError.value(
        totalFileSize,
        'totalFileSize',
        'Must equal totalLength ($totalLength)',
      );
    }

    var len = 0;

    for (var part in _parts) {
      len += _partHeader(part).length;
      len += part.$2 - part.$1 + 1;
      len += 2; // CRLF
    }

    return len + _closingBoundary.length;
  }

  @override
  Stream<List<int>> bind(Stream<List<int>> stream) async* {
    var parts = _parts;
    var i = 0;
    var position = 0;
    var started = false;

    // Breaking out of this loop cancels the subscription to the input.
    await for (var chunk in stream) {
      var chunkEnd = position + chunk.length;

      while (i < parts.length && parts[i].$1 < chunkEnd) {
        var (first, last) = parts[i];

        if (!started) {
          yield _partHeader(parts[i]);
          started = true;
        }

        var from = max(first, position) - position;
        var to = min(last + 1, chunkEnd) - position;
        if (to > from) yield chunk.sublist(from, to);

        // Stop if this part continues into the next chunk.
        if (last >= chunkEnd) break;
        yield const [$cr, $lf];
        started = false;
        i++;
      }

      position = chunkEnd;
      if (i == parts.length) break;
    }

    if (i < parts.length) {
      throw StateError(
        'The input stream ended after $position bytes, before the requested ranges.',
      );
    }

    yield _closingBoundary;
  }
}

var _rnd = Random();
String _randomString({
  int length = 32,
  String validChars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789',
}) {
  var len = _rnd.nextInt((length - 10)) + 10;
  var buf = StringBuffer();

  while (buf.length < len) {
    buf.writeCharCode(validChars.codeUnitAt(_rnd.nextInt(validChars.length)));
  }

  return buf.toString();
}
