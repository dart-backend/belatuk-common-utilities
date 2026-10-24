import 'dart:convert';
import 'dart:typed_data';

import 'package:belatuk_body_parser/belatuk_body_parser.dart';
import 'package:http_parser/http_parser.dart';
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
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(result.body, isEmpty, reason: 'storeOriginalBuffer: $store');
      expect(result.files, isEmpty);
    }
  });
}
