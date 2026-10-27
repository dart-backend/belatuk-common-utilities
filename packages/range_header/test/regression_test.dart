import 'dart:async';
import 'dart:convert';

import 'package:belatuk_range_header/belatuk_range_header.dart';
import 'package:test/test.dart';

/// The bytes `0123456789` repeated, sent in chunks of [chunkSize].
Stream<List<int>> input(int length, {int chunkSize = 7}) async* {
  var bytes = List.generate(length, (i) => 48 + i % 10);
  for (var i = 0; i < length; i += chunkSize) {
    yield bytes.sublist(i, i + chunkSize > length ? length : i + chunkSize);
  }
}

Future<String> transform(String range, int length, {int chunkSize = 7}) {
  var transformer = RangeHeaderTransformer(
    RangeHeader.parse(range),
    'text/plain',
    length,
    boundary: 'B',
  );
  return input(
    length,
    chunkSize: chunkSize,
  ).transform(transformer).expand((b) => b).toList().then(ascii.decode);
}

/// The expected multipart output for the given `(contentRange, body)` parts.
String multipart(List<(String, String)> parts) => [
  for (var (contentRange, body) in parts)
    '--B\r\nContent-Type: text/plain\r\nContent-Range: bytes $contentRange\r\n\r\n$body\r\n',
  '--B--\r\n',
].join();

void main() {
  group('overlaps', () {
    test('disjoint ranges do not merge', () {
      var r = RangeHeader.parse('bytes=5-10,0-2');
      expect(r.items.map((i) => '$i'), ['0-2', '5-10']);
    });

    test('a range inside another merges in either order', () {
      expect(RangeHeader.parse('bytes=0-10,5-8').items.map((i) => '$i'), [
        '0-10',
      ]);
      expect(RangeHeader.parse('bytes=5-8,0-10').items.map((i) => '$i'), [
        '0-10',
      ]);
    });

    test('merging with an open-ended range keeps the open end', () {
      expect(RangeHeader.parse('bytes=0-600,500-').items.map((i) => '$i'), [
        '0-',
      ]);
    });

    test('suffix ranges merge with each other only', () {
      expect(RangeHeader.parse('bytes=-500,-200').items.map((i) => '$i'), [
        '-500',
      ]);
      expect(RangeHeader.parse('bytes=-500,0-10').items, hasLength(2));
    });
  });

  test('fold: false keeps the ranges as sent', () {
    var r = RangeHeader.parse('bytes=5-10,0-2,1-3', fold: false);
    expect(r.items.map((i) => '$i'), ['5-10', '0-2', '1-3']);
  });

  group('parser', () {
    test('rejects a range that ends before it starts', () {
      expect(
        () => RangeHeader.parse('bytes=10-5'),
        throwsA(isA<RangeHeaderParseException>()),
      );
    });

    test('rejects trailing text', () {
      expect(
        () => RangeHeader.parse('bytes=0-10 20'),
        throwsA(isA<RangeHeaderParseException>()),
      );
    });
  });

  group('toContentRange', () {
    test('suffix range', () {
      expect(
        const RangeHeaderItem(-1, 500).toContentRange(10000),
        '9500-9999/10000',
      );
    });

    test('end past the last byte', () {
      expect(const RangeHeaderItem(0, 99).toContentRange(10), '0-9/10');
    });

    test('unknown total size', () {
      expect(const RangeHeaderItem(0, 9).toContentRange(), '0-9/*');
    });
  });

  group('transformer', () {
    test('writes inclusive ranges with well-formed headers', () async {
      expect(
        await transform('bytes=0-9,20-24', 100),
        multipart([('0-9/100', '0123456789'), ('20-24/100', '01234')]),
      );
    });

    test('suffix range returns the last bytes', () async {
      expect(
        await transform('bytes=-5', 100),
        multipart([('95-99/100', '56789')]),
      );
    });

    test('writes ranges in input order, and merges overlaps', () async {
      expect(
        await transform('bytes=-3,0-1', 10, chunkSize: 1),
        multipart([('0-1/10', '01'), ('7-9/10', '789')]),
      );
      expect(
        await transform('bytes=0-8,-3', 10),
        multipart([('0-9/10', '0123456789')]),
      );
    });

    test('content length matches the output', () async {
      for (var range in [
        'bytes=0-9,20-24',
        'bytes=-5',
        'bytes=3-',
        'bytes=0-999',
      ]) {
        var transformer = RangeHeaderTransformer(
          RangeHeader.parse(range),
          'text/plain',
          100,
          boundary: 'B',
        );
        var out = await input(100)
            .transform(transformer)
            .expand((b) => b)
            .toList();
        expect(
          transformer.computeContentLength(100),
          out.length,
          reason: range,
        );
      }
    });

    test('content length rejects a different size', () {
      var transformer = RangeHeaderTransformer(
        RangeHeader.parse('bytes=0-9'),
        'a/b',
        100,
      );
      expect(() => transformer.computeContentLength(50), throwsArgumentError);
    });

    test('rejects ranges that cannot be satisfied', () {
      expect(
        () =>
            RangeHeaderTransformer(RangeHeader.parse('bytes=200-'), 'a/b', 100),
        throwsArgumentError,
      );
    });

    test('a short input fails and closes the stream', () async {
      var transformer = RangeHeaderTransformer(
        RangeHeader.parse('bytes=0-99'),
        'a/b',
        100,
      );
      var done = input(10).transform(transformer).drain<void>();
      await expectLater(done, throwsStateError);
    });

    test('stops reading once the ranges are written', () async {
      var cancelled = Completer<void>();
      var ctrl = StreamController<List<int>>(onCancel: cancelled.complete);
      var transformer = RangeHeaderTransformer(
        RangeHeader.parse('bytes=0-1'),
        'a/b',
        100,
      );
      var output = ctrl.stream.transform(transformer).drain<void>();
      ctrl.add([1, 2, 3]);
      await output;
      await cancelled.future.timeout(const Duration(seconds: 1));
    });
  });
}
