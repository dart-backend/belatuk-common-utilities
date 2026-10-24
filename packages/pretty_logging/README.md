# Belatuk Pretty Logging

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/belatuk_pretty_logging?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dart-backend/belatuk-common-utilities)](https://github.com/dart-backend/belatuk-common-utilities/blob/main/packages/pretty_logging/LICENSE)

Standalone helper for colorful logging output, using pkg:io AnsiCode.

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  belatuk_pretty_logging: ^7.0.0
```

## Usage

Basic usage is very simple:

```dart
myLogger.onRecord.listen(prettyLog);
```

However, you can conditionally pass logic to omit printing an error, provide colors, or to provide a custom print function:

```dart
import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:belatuk_pretty_logging/belatuk_pretty_logging.dart';
import 'package:io/ansi.dart';

myLogger.onRecord.listen(
  (record) => prettyLog(
    record,
    logColorChooser: (_) => red,
    printFunction: stderr.writeln,
    omitError: (r) {
      var err = r.error;
      return err is AngelHttpException && err.statusCode != 500;
    },
  ),
);
```

`omitError` is only asked about records that have an error or a stack trace. Returning `true` hides the error and stack trace; the record's message is still printed.

To drop whole records, such as routine 404s, filter them out before they reach `prettyLog`:

```dart
myLogger.onRecord
    .where((r) {
      var err = r.error;
      return !(err is AngelHttpException && err.statusCode != 500);
    })
    .listen(prettyLog);
```
