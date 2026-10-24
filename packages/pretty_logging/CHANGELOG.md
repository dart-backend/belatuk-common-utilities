# Change Log

## 7.0.0

### Breaking changes in 7.0.0

* **Breaking:** When `omitError` returns `true`, the record's message and stack trace are printed and only its error is hidden. Before, the whole record was dropped. Pass the same check as `omitStackTrace` to hide the stack trace too, and filter `onRecord` before it reaches `prettyLog` to drop records, as the README shows.
* **Breaking:** A stack trace is printed even when the record has no error, as when package:logging's `recordStackTraceAtLevel` adds one. Before, it was never printed. Use `omitStackTrace` to hide it.
* **Breaking:** A record, with its error and stack trace, is passed to `printFunction` in one call, with its lines joined by newlines. Before, the message, error and stack trace were separate calls, so a print function that prefixes each call now prefixes only the first line.
* **Breaking:** `chooseLogColor` colors levels by value, so a custom level gets the color of the nearest built-in level at or below it, such as red for `Level('CRITICAL', 1100)`, instead of none. `Level.ALL` is now light gray; `Level.OFF` is still not colored.

### New in 7.0.0

* `prettyLog` takes an `omitStackTrace` callback that hides the stack trace of a record, including a record without an error, in that listener only.

### Fixes in 7.0.0

* **prettyLog:** A record with an error no longer prints an extra blank line after its message.
* **prettyLog:** The message, error and stack trace are split into lines on `\n`, `\r\n` and a lone `\r`, so no stray carriage return is left inside a colored line, and trailing newlines, as at the end of a stack trace, no longer print blank lines. A message containing `\r`, such as a progress line, is printed as separate lines.
* **prettyLog:** Each line of a record is colored on its own, so the color survives tools that read output line by line, and a cut-off view cannot leave the color on.
* **Docs:** The README's advanced example now compiles and shows its imports, and the title is spelled correctly.

## 6.5.0

* Require Dart >= 3.13

## 6.4.0

* Require Dart >= 3.8

## 6.3.0

* Require Dart >= 3.5
* Updated `lints` to 5.0.0

## 6.2.0

* Require Dart >= 3.3
* Updated `lints` to 4.0.0

## 6.1.0

* Updated `lints` to 3.0.0

## 6.0.0

* Require Dart >= 3.0

## 6.0.0-beta.1

* Require Dart >= 3.0

## 5.0.0

* Require Dart >= 2.17

## 4.0.0

* Added `lints` linter
* Removed deprecated parameters
* Published as `belatuk_pretty_logging` package

## 3.0.3

* Updated README

## 3.0.2

* Updated README

## 3.0.1

* Fixed invalid homepage url in pubspec.yaml

## 3.0.0

* Migrated to support Dart SDK 2.12.x NNBD

## 2.0.0

* Migrated to work with Dart SDK 2.12.x Non NNBD

## 1.0.0

* Initial release.
