# Change Log

## 7.0.0

### Breaking changes in 7.0.0

* **Breaking:** When `omitError` returns `true`, the record's message is printed and only its error and stack trace are hidden, as the doc comment said. Before, the whole record was dropped, so there is no longer a way to drop a record with `omitError`.
* **Breaking:** A record, with its error and stack trace, is passed to `printFunction` in one call, with its lines joined by newlines. Before, the message, error and stack trace were separate calls, so a print function that prefixes each call now prefixes only the first line.
* **Breaking:** `chooseLogColor` colors levels by value, so a custom level gets the color of the nearest built-in level at or below it, such as red for `Level('CRITICAL', 1100)`, instead of none. `Level.ALL` is now light gray; `Level.OFF` is still not colored.

### Fixes in 7.0.0

* **prettyLog:** A record with an error no longer prints an extra blank line after its message.
* **prettyLog:** A stack trace is printed even when the record has no error, as when `Logger.recordStackTraceAtLevel` adds one.
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
