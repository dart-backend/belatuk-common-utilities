# Belatuk Pretty Logging

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/belatuk_pretty_logging?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dart-backend/belatuk-common-utilities)](https://github.com/dart-backend/belatuk-common-utilities/blob/main/packages/pretty_logging/LICENSE)

A listener for [package:logging](https://pub.dev/packages/logging) that prints each `LogRecord`, with its error and stack trace, in a color chosen by its level. Colors are written as ANSI escape codes from [package:io](https://pub.dev/packages/io), and are left out when the terminal does not support them.

## Installation

```yaml
dependencies:
  belatuk_pretty_logging: ^7.0.0
```

## Usage

Pass `prettyLog` to a logger's `onRecord` stream.

```dart
import 'package:belatuk_pretty_logging/belatuk_pretty_logging.dart';
import 'package:logging/logging.dart';

void main() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen(prettyLog);

  var log = Logger('my_app');
  log.info('Server started');
  log.fine('Loaded 3 routes');
  log.severe('Request failed', StateError('Connection closed'));
}
```

This prints the following, with the `INFO` line in cyan, the `FINE` line in light gray and the `SEVERE` lines in red:

```text
[INFO] my_app: Server started
[FINE] my_app: Loaded 3 routes
[SEVERE] my_app: Request failed
Bad state: Connection closed
```

## What is printed

Each record is printed as `[LEVEL] loggerName: message`, which is the record's `toString()`. It does not include the time. The record's error and stack trace, if it has them, follow on their own lines. A stack trace is printed even when the record has no error, as when package:logging's `recordStackTraceAtLevel` adds one.

The message, error and stack trace are split into lines on `\n`, `\r\n` and a lone `\r`, and trailing empty lines, such as the newline a stack trace ends with, are dropped. Each line is colored on its own, so the color survives tools that read the output line by line. The lines are then joined with `\n` and passed to the print function in one call, so a record is never split across several calls.

## Options

`prettyLog` takes the record and these optional named parameters:

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `omitError` | `bool Function(LogRecord)?` | Never hide | Return `true` to hide the record's error. Only called when the record has an error. |
| `omitStackTrace` | `bool Function(LogRecord)?` | Never hide | Return `true` to hide the record's stack trace. Only called when the record has a stack trace. |
| `printFunction` | `void Function(String)?` | `print` | Called once for each record, with all its lines. |
| `logColorChooser` | `AnsiCode Function(Level)?` | `chooseLogColor` | Chooses the color for a record's level. |

To pass options, call `prettyLog` from your own listener:

```dart
Logger.root.onRecord.listen(
  (record) => prettyLog(record, printFunction: stderr.writeln),
);
```

## Hiding errors and stack traces

`omitError` hides a record's error and `omitStackTrace` hides its stack trace. They are independent, so pass both to hide both. The record's message is always printed.

```dart
// Expected errors, such as bad user input, need no stack trace.
bool isExpected(LogRecord record) => record.error is FormatException;

void main() {
  Logger.root.onRecord.listen(
    (record) =>
        prettyLog(record, omitError: isExpected, omitStackTrace: isExpected),
  );

  var log = Logger('my_app');
  log.warning('Invalid input', FormatException('Bad id'), StackTrace.current);
}
```

This prints only the message:

```text
[WARNING] my_app: Invalid input
```

To print only each record's message, hiding every error and stack trace, return `true` from both:

```dart
void quietLog(LogRecord record) =>
    prettyLog(record, omitError: (_) => true, omitStackTrace: (_) => true);
```

## Dropping records

`prettyLog` prints every record it is given. To drop whole records, filter the stream before it reaches `prettyLog`:

```dart
Logger.root.onRecord
    .where((record) => record.error is! FormatException)
    .listen(prettyLog);
```

## Colors

By default, `chooseLogColor` chooses the color. It compares levels by value, so a custom level, such as `Level('CRITICAL', 1100)`, gets the color of the nearest built-in level at or below it.

| Level | Color |
| --- | --- |
| `SHOUT` and above | Red background (`backgroundRed`) |
| `SEVERE` up to `SHOUT` | Red (`red`) |
| `WARNING` up to `SEVERE` | Yellow (`yellow`) |
| `INFO` up to `WARNING` | Cyan (`cyan`) |
| Below `INFO`, including `CONFIG`, `FINE`, `FINER`, `FINEST` and `ALL` | Light gray (`lightGray`) |
| `OFF` | Not colored |

To use your own colors, pass a `logColorChooser` that returns one of the `AnsiCode` constants from `package:io/ansi.dart`. To import it, add [io](https://pub.dev/packages/io) to your own dependencies. Returning `resetAll` leaves a record uncolored.

```dart
AnsiCode myColors(Level level) => level >= Level.WARNING ? magenta : resetAll;

void main() {
  Logger.root.onRecord.listen(
    (record) => prettyLog(record, logColorChooser: myColors),
  );
}
```

Colors are only written when package:io's `ansiOutputEnabled` is `true`. By default, it is `true` when both `stdout` and `stderr` support ANSI escape codes, so output redirected to a file is not colored. To turn colors on or off yourself, call `prettyLog` inside `overrideAnsiOutput`. Wrapping the logging call instead has no effect, because the listener runs in the zone where it was added.

```dart
Logger.root.onRecord.listen(
  (record) => overrideAnsiOutput(false, () => prettyLog(record)),
);
```

## Custom print functions

`printFunction` receives each record as one string, with its lines joined by `\n`. Use it to write to `stderr`, a file or another logging system. A print function that adds a prefix, such as a timestamp, prefixes only the first line of a record.

```dart
void main() {
  Logger.root.onRecord.listen(
    (record) => prettyLog(
      record,
      printFunction: (text) => stderr.writeln('${record.time} $text'),
    ),
  );

  Logger('my_app').info('Server started');
}
```

This prints, for example:

```text
2026-10-27 09:15:02.123456 [INFO] my_app: Server started
```

## Limitations

package:io uses `dart:io`, so this package cannot be used on the web.

## Upgrading from 6.x

Version 7.0.0 changes what is printed. Most notably, `omitError` now hides only the error instead of dropping the whole record, and a stack trace is printed even when a record has no error. See the [changelog](CHANGELOG.md) for the full list.
