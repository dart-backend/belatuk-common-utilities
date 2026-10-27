# Belatuk Range Header

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/belatuk_range_header?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![License](https://img.shields.io/github/license/dart-backend/belatuk-common-utilities)](https://github.com/dart-backend/belatuk-common-utilities/blob/main/packages/range_header/LICENSE)

A parser for the HTTP `Range` request header ([RFC 7233](https://httpwg.org/specs/rfc7233.html)), with a stream transformer that turns a file's bytes into a `multipart/byteranges` response body. It works with `dart:io` or any Dart server framework.

## Installation

```yaml
dependencies:
  belatuk_range_header: ^7.0.0
```

## Parsing a header

`RangeHeader.parse` takes the header's value and returns a `RangeHeader` with its `rangeUnit` and a list of `items`. Whitespace is ignored.

```dart
var header = RangeHeader.parse('bytes=0-499, 1000-');

print(header.rangeUnit); // bytes
print(header.items); // [0-499, 1000-]
```

By default, the items are folded: overlapping ranges are merged, and the result is sorted by start. Ranges that only touch, such as `0-9` and `10-19`, are not merged. Pass `fold: false` to keep the ranges as they were sent, and call `RangeHeader.foldItems` to fold them later.

```dart
var folded = RangeHeader.parse('bytes=500-600, 0-100, 50-200');
print(folded.items); // [0-200, 500-600]

var unfolded = RangeHeader.parse('bytes=500-600, 0-100', fold: false);
print(unfolded.items); // [500-600, 0-100]
```

Only the `bytes` unit is accepted by default. Pass `allowedRangeUnits` to accept others.

```dart
var header = RangeHeader.parse('items=0-9', allowedRangeUnits: ['items']);
print(header.rangeUnit); // items
```

A malformed header throws an exception:

| Exception | Thrown when | Example |
| --- | --- | --- |
| `RangeHeaderParseException`, a `FormatException` | The text has an unknown unit or character, no ranges, a range that ends before it starts, or text after the last range | `bytes=10-5` |
| `InvalidRangeHeaderException` | The text does not start with a range unit, or is empty | `0-499` |

You can also create a header yourself with `RangeHeader(items, rangeUnit: 'bytes')`. The unit defaults to `bytes`.

## Ranges

Each item is a `RangeHeaderItem` with a `start` and an `end`, both inclusive. An unknown start or end is `-1`.

| Range | `start` | `end` | Means |
| --- | --- | --- | --- |
| `0-499` | `0` | `499` | Bytes 0 to 499 |
| `500-` | `500` | `-1` | Byte 500 to the end |
| `-500` | `-1` | `500` | The last 500 bytes |

`toContentRange(totalSize)` gives the value of a `Content-Range` header for the range, without the unit. A suffix range covers the last bytes of `totalSize`, and an end past the last byte is cut back to it. Without `totalSize`, the size is written as `*`, and a range with an unknown start or end throws an `UnsupportedError`.

```dart
var size = 10000;

print(RangeHeaderItem(0, 499).toContentRange(size)); // 0-499/10000
print(RangeHeaderItem(500).toContentRange(size)); // 500-9999/10000
print(RangeHeaderItem(-1, 500).toContentRange(size)); // 9500-9999/10000
print(RangeHeaderItem(0, 99999).toContentRange(size)); // 0-9999/10000
print(RangeHeaderItem(0, 499).toContentRange()); // 0-499/*
```

`toContentRange` does not check that the range can be satisfied: a range that starts past the end, such as `200-` for a 100-byte file, gives an invalid value. Check this first, as in the example below.

`overlaps`, `consolidate` and `compareTo` are what folding uses. A suffix range's position depends on the total size, so it only overlaps other suffix ranges.

## Serving ranges with `dart:io`

A server answers a request for one range with a `206 Partial Content` response containing that range, and a request for several ranges with a `206` response of type `multipart/byteranges`. If none of the ranges can be satisfied, it answers `416 Range Not Satisfiable`. If the header cannot be parsed, it can ignore the header and send the whole file.

```dart
Future<void> serveFile(HttpRequest request, File file, String mimeType) async {
  var response = request.response;
  var total = await file.length();
  response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');

  var header = parseRange(request.headers.value(HttpHeaders.rangeHeader));

  if (header == null) {
    response.headers.contentType = ContentType.parse(mimeType);
    response.contentLength = total;
    await file.openRead().pipe(response);
  } else if (header.items.length == 1) {
    await serveSingleRange(response, file, mimeType, total, header.items[0]);
  } else {
    await serveMultipleRanges(response, file, mimeType, total, header);
  }
}

/// Returns `null` if there is no `Range` header, or it cannot be parsed.
RangeHeader? parseRange(String? value) {
  if (value == null) return null;
  try {
    return RangeHeader.parse(value);
  } on RangeHeaderParseException {
    return null;
  } on InvalidRangeHeaderException {
    return null;
  }
}

Future<void> rangeNotSatisfiable(HttpResponse response, int total) {
  response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
  response.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$total');
  return response.close();
}
```

### A single range

Work out the first and last byte of the range, in the same way as `toContentRange`, and answer `416` if the range starts past the end of the file. Then set `Content-Range` and `Content-Length`, and send only those bytes.

```dart
Future<void> serveSingleRange(
  HttpResponse response,
  File file,
  String mimeType,
  int total,
  RangeHeaderItem item,
) async {
  var first = item.start == -1 ? max(0, total - item.end) : item.start;
  var last = item.start == -1 || item.end == -1
      ? total - 1
      : min(item.end, total - 1);
  if (first > last) return rangeNotSatisfiable(response, total);

  response.statusCode = HttpStatus.partialContent;
  response.headers.contentType = ContentType.parse(mimeType);
  response.headers.set(
    HttpHeaders.contentRangeHeader,
    'bytes ${item.toContentRange(total)}',
  );
  response.contentLength = last - first + 1;
  await file.openRead(first, last + 1).pipe(response);
}
```

### Several ranges

`RangeHeaderTransformer` takes the header, the MIME type of the file and its total length, and transforms the whole file into a `multipart/byteranges` body. Each part has its own `Content-Type` and `Content-Range` headers. Ranges are written in order of their position in the file, and overlapping ranges are merged, so the file is only read once. Ranges that start past the end of the file are left out, and ranges that end past it are cut back to its last byte.

The constructor throws an `ArgumentError` if none of the ranges can be satisfied; answer `416` in that case. Use the transformer's `boundary` in the `Content-Type` header, and `computeContentLength()` for the `Content-Length`.

```dart
Future<void> serveMultipleRanges(
  HttpResponse response,
  File file,
  String mimeType,
  int total,
  RangeHeader header,
) async {
  RangeHeaderTransformer transformer;
  try {
    transformer = RangeHeaderTransformer(header, mimeType, total);
  } on ArgumentError {
    return rangeNotSatisfiable(response, total);
  }

  response.statusCode = HttpStatus.partialContent;
  response.headers.contentType = ContentType(
    'multipart',
    'byteranges',
    parameters: {'boundary': transformer.boundary},
  );
  response.contentLength = transformer.computeContentLength();
  await file.openRead().transform(transformer).pipe(response);
}
```

The boundary is a random string of letters and digits. Pass `boundary` to the constructor to choose your own.

## Limitations

The transformer reads its input from the start and counts bytes from there, so give it the whole file, not a part of it. If the input ends before the requested ranges, the output stream fails with a `StateError`.

Range units are matched case-sensitively, so `Bytes=0-499` throws a `RangeHeaderParseException`.

## Upgrading from 6.x

Version 7.0.0 rejects more malformed headers, such as `bytes=10-5`, and `RangeHeaderTransformer` now sorts and merges ranges and throws an `ArgumentError` when none of them can be satisfied. See the [changelog](CHANGELOG.md) for the full list.
