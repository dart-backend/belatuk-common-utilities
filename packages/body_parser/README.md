# Belatuk Body Parser

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/belatuk_body_parser?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![License](https://img.shields.io/github/license/dart-backend/belatuk-common-utilities)](https://github.com/dart-backend/belatuk-common-utilities/blob/main/packages/body_parser/LICENSE)

A library to parse the query string and body of an HTTP request, similar to Express.js's `body-parser`. It parses JSON, URL-encoded and multipart bodies, builds nested maps and lists from keys such as `user.name` and `tags[]`, converts numbers, and collects uploaded files. It works with a `dart:io` `HttpRequest` or any other stream of bytes.

## Installation

```yaml
dependencies:
  belatuk_body_parser: ^6.0.0
  http_parser: ^4.0.0
```

`http_parser` provides the `MediaType` class that describes the request's content type.

## Parsing a request

`parseBodyFromStream` takes the body as a `Stream<Uint8List>`, the content type and the request URI, and returns a `BodyParseResult`. An `HttpRequest` is such a stream.

```dart
import 'dart:convert';
import 'dart:io';

import 'package:belatuk_body_parser/belatuk_body_parser.dart';
import 'package:http_parser/http_parser.dart';

void main() async {
  var server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);

  await for (var request in server) {
    var contentType = request.headers.contentType;
    var result = await parseBodyFromStream(
      request,
      contentType == null ? null : MediaType.parse(contentType.toString()),
      request.uri,
    );

    if (result.error != null) {
      request.response.statusCode = HttpStatus.badRequest;
    } else {
      request.response
        ..headers.contentType = ContentType.json
        ..write(json.encode({'query': result.query, 'body': result.body}));
    }

    await request.response.close();
  }
}
```

The older `parseBody(request)` does the same, but is deprecated.

Because it only needs a stream, `parseBodyFromStream` also works with other servers, or with a body you already have:

```dart
var result = await parseBodyFromStream(
  Stream.value(utf8.encode('name=Ann&tags[]=a&tags[]=b&user.age=30')),
  MediaType('application', 'x-www-form-urlencoded'),
  Uri.parse('/search?page=2&debug'),
);

print(result.query); // {page: 2, debug: true}
print(result.body); // {name: Ann, tags: [a, b], user: {age: 30}}
```

## The result

| Property | Contains |
| --- | --- |
| `query` | The parsed query string. It is parsed for every request, whatever the content type |
| `body` | The parsed body, or an empty map if the body was not parsed |
| `files` | The files uploaded in a multipart body, as `FileUploadInfo` objects |
| `originalBuffer` | The raw body bytes, if `storeOriginalBuffer` is `true`. Otherwise `null` |
| `error`, `stack` | The error and stack trace if parsing failed. Otherwise `null` |

## Content types

| Content type | How the body is parsed |
| --- | --- |
| `application/json` | Decoded as JSON, which must be an object. Its keys and values are kept as they are |
| `application/x-www-form-urlencoded` | Split into keys and values, which are URL-decoded and then follow the rules below |
| `multipart/*` with a `boundary` | Text fields go into `body`, following the rules below, and files go into `files` |
| Anything else | Not parsed, and the body is not read |

When the body is not parsed, it is left for you to read or drain, unless `storeOriginalBuffer` is `true`, in which case it is read into `originalBuffer`.

## Keys

In the query string, a URL-encoded body and multipart field names, keys can build nested maps and lists:

| Input | Result |
| --- | --- |
| `name=Ann` | `{name: Ann}` |
| `name=Ann&name=Bob` | `{name: Bob}`. A repeated key keeps the last value |
| `tags[]=a&tags[]=b` | `{tags: [a, b]}` |
| `user.name=Ann&user.age=30` | `{user: {name: Ann, age: 30}}` |
| `user.tags[]=a` | `{user: {tags: [a]}}` |
| `debug` | `{debug: true}`. A key without `=` gets the value `true` |

`[]` can only appear once, at the end of a key, so there are no lists of maps or lists of lists. Empty pairs, such as in `a=1&&b=2`, and pairs without a key, such as `=v`, are skipped.

These keys fail the parse with a `FormatException`:

* A key that conflicts with an earlier one, such as `user` and `user.name`, or `tags` and `tags[]`.
* A key with an empty segment, such as `a.` or `a..b`, or with `[]` anywhere but once at the end, such as `a[].b` or `a[][]`.
* A key that contains a control character, a line break or a bidi control, so that it cannot inject a line break into a log or header.

Keys inside a JSON body are data, so none of these rules apply to them.

## Values

Values from the query string, a URL-encoded body and multipart text fields are converted:

| Value | Result |
| --- | --- |
| A plain decimal that converts exactly, such as `42`, `-7` or `14.5` | An `int` or `double` |
| Other numbers, such as `01234`, `+1555`, `1e3`, `0x1F` or `Infinity` | A `String` |
| An integer too large for an `int`, or a decimal with more than 15 significant digits | A `String` |
| Valid JSON in `[]` or `{}`, such as `[1,2]` or `{"a":1}` | The decoded list or map |
| Text that only looks like JSON, such as `[draft]` | A `String` |
| `null`, in any case | `null` |
| Anything else, including `true` and `false` | A `String` |

`-0` and `-0.0` lose their sign, and become `0` and `0.0`.

## Character sets

Text is decoded as UTF-8 unless the content type declares `charset=us-ascii`. Any other charset, or bytes that are not valid for the charset, fail the parse with a `FormatException`. This applies to JSON and URL-encoded bodies, and to each multipart text field, which can declare its own charset.

In a URL-encoded body or query string, `%XX` escapes must decode to valid UTF-8. A `%` that does not start an escape, and raw non-ASCII characters, are kept as they are.

## File uploads

In a multipart body, a part is a file if it has a `filename`, or a `Content-Type` other than `text/*` or `application/json`. Each file becomes a `FileUploadInfo`:

```dart
var body =
    '--boundary\r\n'
    'Content-Disposition: form-data; name="title"\r\n'
    '\r\n'
    'Holiday\r\n'
    '--boundary\r\n'
    'Content-Disposition: form-data; name="photo"; filename="beach.jpg"\r\n'
    'Content-Type: image/jpeg\r\n'
    '\r\n'
    'JPEG data\r\n'
    '--boundary--\r\n';

var result = await parseBodyFromStream(
  Stream.value(utf8.encode(body)),
  MediaType('multipart', 'form-data', {'boundary': 'boundary'}),
  Uri.parse('/upload'),
);

print(result.body); // {title: Holiday}
for (var file in result.files) {
  // photo beach.jpg image/jpeg 9
  print('${file.name} ${file.filename} ${file.mimeType} ${file.data.length}');
}
```

| Property | Contains |
| --- | --- |
| `name` | The field name |
| `filename` | The filename sent by the client, or `file` if the part has no filename, or an empty one |
| `mimeType` | The part's content type, or `text/plain` if it has none |
| `data` | The file's bytes, exactly as sent |

A file input left blank, which browsers send as an empty filename with no content, is not added to `files`.

In field names and filenames, only the `%22` that browsers send for `"` is decoded. A filename that contains a line break, a control character other than tab, or a bidi override fails the parse with a `FormatException`. A filename can still contain `"`, `/`, `\` and `..`, so escape it before putting it in a header, and clean it before using it as a path.

Text fields are not URL-decoded, so `+` and `%XX` are kept as sent. A text field without a name is dropped. A part without a `Content-Disposition` header, or with a `Content-Transfer-Encoding` other than `7bit`, `8bit` or `binary`, fails the parse with an `HttpException`.

## Errors

`parseBodyFromStream` does not throw when the input is bad. Instead, it sets `error` and `stack` on the result, and leaves `body` and `files` empty. A bad query string fails the whole request, so `query` is empty too and the body is not parsed.

```dart
var result = await parseBodyFromStream(
  Stream.value(utf8.encode('[1, 2, 3]')),
  MediaType('application', 'json'),
  Uri.parse('/'),
);

print(result.error); // FormatException: A JSON body must be an object
```

Most errors are a `FormatException`. A bad multipart part gives an `HttpException`, and a malformed multipart body can also give the `mime` package's `MimeMultipartException`.

After an error, the rest of the body is still read, so that it does not stall the connection. The exception is a multipart body that is broken, such as one with a malformed part header or one cut off part-way: the parse stops, and the rest of it is not read.

## Reading the raw body

To handle a content type that is not parsed, such as GraphQL, pass `storeOriginalBuffer: true` and read the bytes from `originalBuffer`. They are stored for every content type, even when the parse fails.

```dart
var result = await parseBodyFromStream(
  Stream.value(utf8.encode('{ hero { name } }')),
  MediaType('application', 'graphql'),
  Uri.parse('/graphql'),
  storeOriginalBuffer: true,
);

print(utf8.decode(result.originalBuffer!)); // { hero { name } }
```

## Limitations

The whole body, including every uploaded file, is held in memory, and there is no size limit. Limit the size of the request before you parse it.

## Upgrading from 5.x

Version 6.0.0 makes parsing stricter. Most notably, only UTF-8 and US-ASCII are accepted, conflicting or malformed keys fail the parse, fewer values are converted to numbers, and multipart text fields are no longer URL-decoded. See the [changelog](CHANGELOG.md) for the full list.
