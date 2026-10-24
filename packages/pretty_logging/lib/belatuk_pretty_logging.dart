import 'package:logging/logging.dart';
import 'package:io/ansi.dart';

/// Prints the contents of a [LogRecord] with pretty colors.
///
/// The record's error and stack trace, if any, follow the message on their own
/// lines. A stack trace is printed even when there is no error, as when
/// [Logger.recordStackTraceAtLevel] adds one. By passing [omitError], you can
/// omit printing the error and stack trace of a [LogRecord] that has either;
/// its message is still printed. To drop whole records, filter the stream
/// before it reaches [prettyLog] instead.
///
/// The whole record is passed to [printFunction] in one call, so a print
/// function that writes each call as its own log entry keeps the record
/// together. Each line is colored on its own, so the color survives tools
/// that read the output line by line.
///
/// You can also pass a custom [printFunction] or [logColorChooser].
void prettyLog(
  LogRecord record, {
  bool Function(LogRecord)? omitError,
  void Function(String)? printFunction,
  AnsiCode Function(Level)? logColorChooser,
}) {
  logColorChooser ??= chooseLogColor;
  printFunction ??= print;

  var parts = [record.toString()];
  var omitted =
      (record.error != null || record.stackTrace != null) &&
      (omitError?.call(record) ?? false);
  if (!omitted) {
    if (record.error != null) {
      parts.add(record.error.toString());
    }
    if (record.stackTrace != null) {
      parts.add(record.stackTrace.toString());
    }
  }

  var code = logColorChooser(record.level);
  printFunction(
    parts
        .expand((part) => part.split(_lineBreakRgx))
        .map((line) => code.wrap(line) ?? line)
        .join('\n'),
  );
}

final _lineBreakRgx = RegExp(r'\r?\n');

/// Chooses a color based on the logger [level].
///
/// Levels are compared by value, so a custom level gets the color of the
/// nearest built-in level at or below it. [Level.OFF] is not colored.
AnsiCode chooseLogColor(Level level) {
  if (level == Level.OFF) {
    return resetAll;
  } else if (level >= Level.SHOUT) {
    return backgroundRed;
  } else if (level >= Level.SEVERE) {
    return red;
  } else if (level >= Level.WARNING) {
    return yellow;
  } else if (level >= Level.INFO) {
    return cyan;
  }
  return lightGray;
}
