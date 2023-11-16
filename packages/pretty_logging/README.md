# Belatuk Petty Logging

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/belatuk_pretty_logging?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dart-backend/belatuk-common-utilities)](https://github.com/dart-backend/belatuk-common-utilities/blob/main/packages/pretty_logging/LICENSE)

**Replacement of `package:pretty_logging` with breaking changes to support NNBD.**

Standalone helper for colorful logging output, using pkg:io AnsiCode.

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  belatuk_pretty_logging: ^8.0.0
```

## Usage

Basic usage is very simple:

```dart
myLogger.onRecord.listen(prettyLog);
```

However, you can conditionally pass logic to omit printing an error, provide colors, or to provide a custom print function:

```dart
var pretty = prettyLog(
  logColorChooser: (_) => red,
  printFunction: stderr.writeln,
  omitError: (r) {
    var err = r.error;
    return err is AngelHttpException && err.statusCode != 500;
  },
);
myLogger.onRecord.listen(pretty);
```
