# Belatuk Range Header

[![version](https://img.shields.io/badge/pub-v4.0.1-brightgreen)](https://pub.dev/packages/belatuk_range_header)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![License](https://img.shields.io/github/license/dart-backend/belatuk-common-utilities)](https://github.com/dart-backend/belatuk-common-utilities/blob/main/packages/range_header/LICENSE)

**Replacement of `package:range_header` with breaking changes to support NNBD.**

Range header parser for belatuk. Can be used by any dart backend.

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  belatuk_range_header: ^4.0.0
```

## Usage

```dart
handleRequest(HttpRequest request) async {
  // Parse the header
  var header = RangeHeader.parse(request.headers.value(HttpHeaders.rangeHeader));

  // Optimize/canonicalize it
  var items = RangeHeader.foldItems(header.items);
  header = RangeHeader(items);

  // Get info
  header.items;
  header.rangeUnit;
  print(header.items[0].toContentRange(fileSize));

  // Serve the file
  var transformer = RangeHeaderTransformer(header);
  await file.openRead().transform(transformer).pipe(request.response);
}
```
