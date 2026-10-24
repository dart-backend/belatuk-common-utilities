import 'dart:convert';
import 'dart:io' show HttpRequest, HttpServer;

import 'package:belatuk_body_parser/belatuk_body_parser.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:test/test.dart';

const token =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiIxMjcuMC4wLjEiLCJleHAiOi0xLCJpYXQiOiIyMDE2LTEyLTIyVDEyOjQ5OjUwLjM2MTQ0NiIsImlzcyI6ImFuZ2VsX2F1dGgiLCJzdWIiOiIxMDY2OTQ4Mzk2MDIwMjg5ODM2NTYifQ==.PYw7yUb-cFWD7N0sSLztP7eeRvO44nu1J2OgDNyT060=';

String jsonEncodeBody(BodyParseResult result) {
  return json.encode({
    'query': result.query,
    'body': result.body,
    'error': result.error?.toString(),
    'files': result.files.map((f) {
      return {
        'name': f.name,
        'mimeType': f.mimeType,
        'filename': f.filename,
        'data': f.data,
      };
    }).toList(),
    'originalBuffer': result.originalBuffer,
    'stack': null, //result.stack.toString(),
  });
}

Future<BodyParseResult> _parseBody(HttpRequest request) {
  return parseBodyFromStream(
    request,
    request.headers.contentType != null
        ? MediaType.parse(request.headers.contentType.toString())
        : null,
    request.uri,
    storeOriginalBuffer: true,
  );
}

void main() {
  HttpServer? server;
  String? url;
  http.Client? client;

  setUp(() async {
    server = await HttpServer.bind('127.0.0.1', 0);
    server!.listen((HttpRequest request) async {
      //Server will simply return a JSON representation of the parsed body
      request.response.write(
        // ignore: deprecated_member_use
        jsonEncodeBody(await _parseBody(request)),
      );
      await request.response.close();
    });
    url = 'http://localhost:${server!.port}';
    print('Test server listening on $url');
    client = http.Client();
  });
  tearDown(() async {
    await server!.close(force: true);
    client!.close();
    server = null;
    url = null;
    client = null;
  });

  group('query string', () {
    test('GET Simple', () async {
      print('GET $url/?hello=world');
      var response = await client!.get(Uri.parse('$url/?hello=world'));
      print('Response: ${response.body}');
      var result = json.decode(response.body);
      expect(result['body'], equals({}));
      expect(result['query'], equals({'hello': 'world'}));
      expect(result['files'], equals([]));
      //expect(result['originalBuffer'], isNull);
    });

    test('GET Complex', () async {
      var postData =
          'hello=world&nums%5B%5D=1&nums%5B%5D=2.0&nums%5B%5D=${3 - 1}&map.foo.bar=baz';
      print('Body: $postData');
      var response = await client!.get(Uri.parse('$url/?$postData'));
      print('Response: ${response.body}');
      var query = json.decode(response.body)['query'];
      expect(query['hello'], equals('world'));
      expect(query['nums'][2], equals(2));
      expect(query['map'] is Map, equals(true));
      expect(query['map']['foo'], equals({'bar': 'baz'}));
    });

    test('JWT', () async {
      var postData = 'token=$token';
      print('Body: $postData');
      var response = await client!.get(Uri.parse('$url/?$postData'));
      print('Response: ${response.body}');
      var query = json.decode(response.body)['query'];
      expect(query['token'], equals(token));
    });
  });

  group('urlencoded', () {
    var headers = <String, String>{
      'content-type': 'application/x-www-form-urlencoded',
    };
    test('POST Simple', () async {
      print('Body: hello=world');
      var response = await client!.post(
        Uri.parse(url!),
        headers: headers,
        body: 'hello=world',
      );
      print('Response: ${response.body}');
      var result = json.decode(response.body);
      expect(result['query'], equals({}));
      expect(result['body'], equals({'hello': 'world'}));
      expect(result['files'], equals([]));
      expect(result['originalBuffer'], isList);
      expect(result['originalBuffer'], isNotEmpty);
    });

    test('Post Complex', () async {
      var postData =
          'hello=world&nums%5B%5D=1&nums%5B%5D=2.0&nums%5B%5D=${3 - 1}&map.foo.bar=baz';
      var response = await client!.post(
        Uri.parse(url!),
        headers: headers,
        body: postData,
      );
      print('Response: ${response.body}');
      var body = json.decode(response.body)['body'];
      expect(body['hello'], equals('world'));
      expect(body['nums'][2], equals(2));
      expect(body['map'] is Map, equals(true));
      expect(body['map']['foo'], equals({'bar': 'baz'}));
    });

    test('JWT', () async {
      var postData = 'token=$token';
      var response = await client!.post(
        Uri.parse(url!),
        headers: headers,
        body: postData,
      );
      var body = json.decode(response.body)['body'];
      expect(body['token'], equals(token));
    });

    test('Query string is parsed alongside the body', () async {
      var response = await client!.post(
        Uri.parse('$url/?page=2'),
        headers: headers,
        body: 'hello=world',
      );
      var result = json.decode(response.body);
      expect(result['error'], isNull);
      expect(result['query'], equals({'page': 2}));
      expect(result['body'], equals({'hello': 'world'}));
    });

    test('Bad query string fails the request', () async {
      var response = await client!.post(
        Uri.parse('$url/?q=%E9'),
        headers: headers,
        body: 'hello=world',
      );
      var result = json.decode(response.body);
      expect(result['error'], contains('FormatException'));
      expect(result['body'], equals({}));
      expect(result['originalBuffer'], equals(utf8.encode('hello=world')));
    });

    test('Empty pairs are skipped', () async {
      var response = await client!.post(
        Uri.parse('$url/?'),
        headers: headers,
        body: 'a=1&&b=2&',
      );
      var result = json.decode(response.body);
      expect(result['error'], isNull);
      expect(result['query'], equals({}));
      expect(result['body'], equals({'a': 1, 'b': 2}));

      response = await client!.post(
        Uri.parse('$url/?x=1&=&=v&=%C3'),
        headers: headers,
        body: '=1&a=1&=%C3',
      );
      result = json.decode(response.body);
      expect(result['error'], isNull);
      expect(result['query'], equals({'x': 1}));
      expect(result['body'], equals({'a': 1}));
    });

    test('Raw non-ASCII is kept, invalid UTF-8 escapes are rejected', () async {
      var response = await client!.post(
        Uri.parse(url!),
        headers: headers,
        body: 'name=café&x=caf%C3%A9 é',
      );
      var result = json.decode(response.body);
      expect(result['error'], isNull);
      expect(result['body'], equals({'name': 'café', 'x': 'café é'}));

      response = await client!.post(
        Uri.parse(url!),
        headers: headers,
        body: 'name=caf%E9',
      );
      expect(json.decode(response.body)['error'], contains('FormatException'));
    });

    test('Non-UTF-8 charset is rejected', () async {
      var response = await client!.post(
        Uri.parse(url!),
        headers: {
          'content-type':
              'application/x-www-form-urlencoded; charset=iso-8859-1',
        },
        body: 'hello=world',
      );
      var result = json.decode(response.body);
      expect(result['error'], contains('Unsupported charset'));
      expect(result['originalBuffer'], equals(utf8.encode('hello=world')));
    });

    test('UTF-8 aliases and US-ASCII are accepted', () async {
      for (var charset in ['utf-8', 'UTF8', 'us-ascii']) {
        var response = await client!.post(
          Uri.parse(url!),
          headers: {
            'content-type':
                'application/x-www-form-urlencoded; charset=$charset',
          },
          body: utf8.encode('hello=world'),
        );
        var result = json.decode(response.body);
        expect(result['error'], isNull, reason: charset);
        expect(result['body'], equals({'hello': 'world'}), reason: charset);
      }
    });

    test('US-ASCII body with non-ASCII bytes is rejected', () async {
      var response = await client!.post(
        Uri.parse(url!),
        headers: {
          'content-type': 'application/x-www-form-urlencoded; charset=us-ascii',
        },
        body: utf8.encode('name=café'),
      );
      var result = json.decode(response.body);
      expect(result['error'], contains('FormatException'));
      expect(result['body'], equals({}));
    });

    test('Stray percent is kept', () async {
      var response = await client!.post(
        Uri.parse(url!),
        headers: headers,
        body: 'note=100%&off=50%2&name=bob%20b',
      );
      var result = json.decode(response.body);
      expect(result['error'], isNull);
      expect(
        result['body'],
        equals({'note': '100%', 'off': '50%2', 'name': 'bob b'}),
      );
    });

    test('Keys with empty or misplaced segments are rejected', () async {
      for (var body in [
        'a.=1',
        '.a=1',
        'a..b=1',
        'a[].b=1',
        'a.[]=1',
        '[]=1',
        'a[][]=1',
        'a[]x=1',
        'a[]b[]=1',
      ]) {
        var response = await client!.post(
          Uri.parse(url!),
          headers: headers,
          body: body,
        );
        expect(
          json.decode(response.body)['error'],
          contains('is not valid'),
          reason: body,
        );
      }
    });

    test('Keys with control characters are rejected', () async {
      for (var body in [
        'a%0D%0AX-Evil:1=1',
        'a%0Ab',
        'a%00=1',
        'a%C2%9B=1',
        // Keys that would also be invalid, or conflict, must not put the line
        // break into those errors' messages.
        'a%0D%0AX-Evil:1.=1',
        'a=1&a.b%0AEvil=2',
        'a%D8%9Cb=1',
      ]) {
        var response = await client!.post(
          Uri.parse(url!),
          headers: headers,
          body: body,
        );
        var error = json.decode(response.body)['error'] as String;
        expect(error, contains('control character'), reason: body);
        expect(error, isNot(contains('Evil')));
      }
    });

    test('Keys inside a JSON-looking value are data', () async {
      var response = await client!.post(
        Uri.parse(url!),
        headers: headers,
        // a={"x\ny":1}
        body: 'a=%7B%22x%5Cny%22%3A1%7D',
      );
      var result = json.decode(response.body);
      expect(result['error'], isNull);
      expect(
        result['body'],
        equals({
          'a': {'x\ny': 1},
        }),
      );
    });

    test('Conflicting keys are rejected', () async {
      for (var body in [
        'user=bob&user.name=x',
        'user.name=x&user=bob',
        'a.b=1&a.b.c=2',
        'tags=x&tags[]=y',
        'tags[]=y&tags=x',
        'items[]=1&items.count=2',
        'user.name=x&user',
        'a={"x":1}&a.y=2',
        'a=[1]&a[]=2',
        'a[]=1&a=[2]',
        'a=null&a.b=1',
        'a=null&a[]=1',
      ]) {
        var response = await client!.post(
          Uri.parse(url!),
          headers: headers,
          body: body,
        );
        expect(
          json.decode(response.body)['error'],
          contains('conflicts with an earlier value'),
          reason: body,
        );
      }
    });

    test('Dotted array keys are nested', () async {
      var response = await client!.post(
        Uri.parse(url!),
        headers: headers,
        body: 'user.name=x&user.tags[]=a&user.tags[]=b&user.tags.x=1',
      );
      var result = json.decode(response.body);
      expect(result['error'], contains('conflicts with an earlier value'));

      response = await client!.post(
        Uri.parse(url!),
        headers: headers,
        body: 'user.name=x&user.tags[]=a&user.tags[]=b',
      );
      result = json.decode(response.body);
      expect(result['error'], isNull);
      expect(
        result['body'],
        equals({
          'user': {
            'name': 'x',
            'tags': ['a', 'b'],
          },
        }),
      );
    });

    test('Repeated and flag keys', () async {
      var response = await client!.post(
        Uri.parse(url!),
        headers: headers,
        body:
            'a=1&a=2&flags[]&opts.debug&user.name=x&user.name=y'
            '&j=[1]&j=[2]&o={"x":1}&o={"x":2}',
      );
      var result = json.decode(response.body);
      expect(result['error'], isNull);
      expect(
        result['body'],
        equals({
          'a': 2,
          'flags': [true],
          'opts': {'debug': true},
          'user': {'name': 'y'},
          'j': [2],
          'o': {'x': 2},
        }),
      );
    });
  });

  group('json', () {
    var headers = <String, String>{'content-type': 'application/json'};
    test('Keys are data, so control characters are allowed', () async {
      var body = {
        'a\r\nb': 1,
        't': {'Hello\nWorld': 'x'},
        'l': [
          {'x\u202Ey': 1},
        ],
      };
      var response = await client!.post(
        Uri.parse(url!),
        headers: headers,
        body: json.encode(body),
      );
      var result = json.decode(response.body);
      expect(result['error'], isNull);
      expect(result['body'], equals(body));
    });

    test('Body that is not an object is rejected', () async {
      for (var body in ['null', '[]', '42', '"x"']) {
        var response = await client!.post(
          Uri.parse(url!),
          headers: headers,
          body: body,
        );
        var result = json.decode(response.body);
        expect(
          result['error'],
          equals('FormatException: A JSON body must be an object'),
          reason: body,
        );
        expect(result['originalBuffer'], equals(utf8.encode(body)));
      }
    });

    test('Post Simple', () async {
      var postData = json.encode({'hello': 'world'});
      print('Body: $postData');
      var response = await client!.post(
        Uri.parse(url!),
        headers: headers,
        body: postData,
      );
      print('Response: ${response.body}');
      var result = json.decode(response.body);
      expect(result['body'], equals({'hello': 'world'}));
      expect(result['query'], equals({}));
      expect(result['files'], equals([]));
      expect(result['originalBuffer'], allOf(isList, isNotEmpty));
    });

    test('Post Complex', () async {
      var postData = json.encode({
        'hello': 'world',
        'nums': [1, 2.0, 3 - 1],
        'map': {
          'foo': {'bar': 'baz'},
        },
      });
      print('Body: $postData');
      var response = await client!.post(
        Uri.parse(url!),
        headers: headers,
        body: postData,
      );
      print('Response: ${response.body}');
      var body = json.decode(response.body)['body'];
      expect(body['hello'], equals('world'));
      expect(body['nums'][2], equals(2));
      expect(body['map'] is Map, equals(true));
      expect(body['map']['foo'], equals({'bar': 'baz'}));
    });
  });
}
