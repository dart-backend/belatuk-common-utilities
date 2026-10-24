import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:io/ansi.dart';

/// Prints the contents of a [LogRecord] with pretty colors.
///
/// The record's error and stack trace, if any, follow the message on their own
/// lines. A stack trace is printed even when there is no error, as when
/// package:logging's [recordStackTraceAtLevel] adds one.
///
/// [omitError] decides whether to hide the error of a [LogRecord] that has
/// one, and [omitStackTrace] whether to hide the stack trace of one that has
/// one. Each is only called when there is something for it to hide, and the
/// record's message is always printed. To drop whole records, filter the
/// stream before it reaches [prettyLog].
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
  bool Function(LogRecord)? omitStackTrace,
  void Function(String)? printFunction,
  AnsiCode Function(Level)? logColorChooser,
}) {
  logColorChooser ??= chooseLogColor;
  printFunction ??= print;

  var parts = [record.toString()];
  if (record.error != null && !(omitError?.call(record) ?? false)) {
    parts.add(record.error.toString());
  }
  if (record.stackTrace != null && !(omitStackTrace?.call(record) ?? false)) {
    parts.add(record.stackTrace.toString());
  }

  var code = logColorChooser(record.level);
  printFunction(
    parts
        .expand(_lines)
        // An empty line is left uncolored, so it is not bare color codes.
        .map((line) => line.isEmpty ? line : code.wrap(line) ?? line)
        .join('\n'),
  );
}

/// Splits [part] on `\n`, `\r\n` and a lone `\r`, and drops trailing empty
/// lines, such as the newline a stack trace ends with, so no blank line
/// follows. A part with no text, such as an empty error, is one empty line, so
/// it still shows.
List<String> _lines(String part) {
  var lines = LineSplitter.split(part).toList();
  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  return lines.isEmpty ? [''] : lines;
}

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
