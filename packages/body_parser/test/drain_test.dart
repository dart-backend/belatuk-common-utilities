import 'dart:convert';
import 'dart:typed_data';

import 'package:belatuk_body_parser/belatuk_body_parser.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:test/test.dart';

void main() {
  // A body in several chunks that records whether it was read to the end.
  late bool readToEnd;
  Stream<Uint8List> body(List<String> chunks) async* {
    for (var chunk in chunks) {
      yield utf8.encode(chunk);
    }
    readToEnd = true;
  }

  setUp(() => readToEnd = false);

  test('Body of an unparsed content type is left for the caller', () async {
    var data = body(['hello', ' world']).asBroadcastStream();
    var result = await parseBodyFromStream(
      data,
      MediaType('text', 'plain'),
      Uri.parse('/'),
    );
    expect(result.error, isNull);
    expect(readToEnd, isFalse);
    expect(await utf8.decoder.bind(data).join(), equals('hello world'));
  });

  test(
    'Unparsed body is left for the caller after a bad query string',
    () async {
      var data = body(['hello', ' world']).asBroadcastStream();
      var result = await parseBodyFromStream(
        data,
        MediaType('text', 'plain'),
        Uri.parse('/?q=%E9'),
      );
      expect(result.error, isA<FormatException>());
      expect(readToEnd, isFalse);
      expect(await utf8.decoder.bind(data).join(), equals('hello world'));
    },
  );

  test('Body is drained after a bad query string', () async {
    var result = await parseBodyFromStream(
      body(['{"a":', '1}']),
      MediaType('application', 'json'),
      Uri.parse('/?q=%E9'),
    );
    expect(result.error, isA<FormatException>());
    expect(result.body, isEmpty);
    expect(readToEnd, isTrue);
  });

  test('Multipart body is drained after a bad part', () async {
    var boundary = 'myBoundary';
    var result = await parseBodyFromStream(
      body([
        '--$boundary\r\nContent-Type: text/plain\r\n\r\nx\r\n',
        '--$boundary\r\nContent-Disposition: form-data; name="a"\r\n\r\n1\r\n',
        '--$boundary--\r\n',
      ]),
      MediaType('multipart', 'form-data', {'boundary': boundary}),
      Uri.parse('/'),
    );
    expect(result.error, isNotNull);
    expect(readToEnd, isTrue);
  });

  test('Failed multipart parse keeps no partial body or files', () async {
    var boundary = 'myBoundary';
    var result = await parseBodyFromStream(
      body([
        '--$boundary\r\n'
            'Content-Disposition: form-data; name="f"; filename="f.txt"\r\n'
            '\r\nfile\r\n',
        '--$boundary\r\nContent-Disposition: form-data; name="a"\r\n\r\n1\r\n',
        '--$boundary\r\nContent-Type: text/plain\r\n\r\nx\r\n',
        '--$boundary\r\nContent-Disposition: form-data; name="b"\r\n\r\n2\r\n',
        '--$boundary--\r\n',
      ]),
      MediaType('multipart', 'form-data', {'boundary': boundary}),
      Uri.parse('/'),
    );
    expect(result.error, isNotNull);
    expect(result.body, isEmpty);
    expect(result.files, isEmpty);
    expect(readToEnd, isTrue);
  });

  test('Broken multipart body stops the parse', () async {
    var boundary = 'myBoundary';
    var result = await parseBodyFromStream(
      body([
        '--$boundary\r\n'
            'Content-Disposition: form-data; name="f"; filename="f.txt"\r\n'
            '\r\nfile\r\n',
        '--$boundary\r\nContent-Disposition: form-data; name="a"\r\n\r\n1\r\n',
        '--$boundary\r\nContent-Disposition: form-data; name="b"\r\n\r\ncut',
      ]),
      MediaType('multipart', 'form-data', {'boundary': boundary}),
      Uri.parse('/'),
    );
    expect(result.error, isNotNull);
    expect(result.body, isEmpty);
    expect(result.files, isEmpty);
  });

  test('Broken multipart body stays empty after the parse returns', () async {
    var boundary = 'myBoundary';
    for (var store in [false, true]) {
      var result = await parseBodyFromStream(
        body([
          for (var name in ['a', 'c', 'd'])
            '--$boundary\r\n'
                'Content-Disposition: form-data; name="$name"\r\n\r\n1\r\n',
        ]),
        MediaType('multipart', 'form-data', {'boundary': boundary}),
        Uri.parse('/'),
        storeOriginalBuffer: store,
      );
      expect(result.error, isNotNull);
      await pumpEventQueue();
      expect(result.body, isEmpty, reason: 'storeOriginalBuffer: $store');
      expect(result.files, isEmpty);
    }
  });

  test('Malformed part header fails the parse instead of hanging', () async {
    var result = await parseBodyFromStream(
      body(['--B\r\nBad Header: x\r\n\r\nv\r\n', '--B--\r\n']),
      MediaType('multipart', 'form-data', {'boundary': 'B'}),
      Uri.parse('/'),
    ).timeout(const Duration(seconds: 2));
    expect(result.error, isA<MimeMultipartException>());
    expect(result.body, isEmpty);
  });

  test('Failed query string keeps no partial query', () async {
    var result = await parseBodyFromStream(
      body([]),
      null,
      Uri.parse('/?a=1&b=%E9'),
    );
    expect(result.error, isA<FormatException>());
    expect(result.query, isEmpty);
  });

  test('Rejected JSON body is still read to the end', () async {
    for (var (chunks, charset) in [
      (
        [
          [0x7B, 0x22, 0x61, 0x22, 0x3A],
          [0x22, 0xE9, 0x22, 0x7D],
        ],
        null,
      ),
      ([utf8.encode('{"a":'), utf8.encode('1}')], 'iso-8859-1'),
    ]) {
      var done = false;
      Stream<Uint8List> bytes() async* {
        for (var chunk in chunks) {
          yield Uint8List.fromList(chunk);
        }
        done = true;
      }

      var result = await parseBodyFromStream(
        bytes(),
        MediaType('application', 'json', {'charset': ?charset}),
        Uri.parse('/'),
      );
      expect(result.error, isA<FormatException>(), reason: charset);
      expect(done, isTrue, reason: charset);
    }
  });

  test('Escaped quotes and newlines in field names are decoded', () async {
    var boundary = 'myBoundary';
    var result = await parseBodyFromStream(
      body([
        '--$boundary\r\n'
            'Content-Disposition: form-data; name="a%22b%0D%0Ac"\r\n\r\n1\r\n',
        '--$boundary\r\n'
            'Content-Disposition: form-data; name="p%25"\r\n\r\n2\r\n',
        '--$boundary\r\n'
            'Content-Disposition: form-data; name="f%22"; '
            'filename="x%22.txt"\r\n\r\nfile\r\n',
        '--$boundary--\r\n',
      ]),
      MediaType('multipart', 'form-data', {'boundary': boundary}),
      Uri.parse('/'),
    );
    expect(result.error, isNull);
    expect(result.body, equals({'a"b\r\nc': 1, 'p%25': 2}));
    expect(result.files.single.name, equals('f"'));
    expect(result.files.single.filename, equals('x".txt'));
  });
}
