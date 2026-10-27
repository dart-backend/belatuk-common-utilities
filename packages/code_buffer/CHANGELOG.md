# Change Log

## 6.0.0

### Breaking changes in 6.0.0

* **Breaking:** `length` matches the length of `toString()`. It now counts indentation, the full `newline` sequence and the trailing newline, and no longer counts a line break after the last line. Span offsets follow the same rule, so each one is the position of its text in `toString()`. With `trailingNewline`, an empty buffer has a `length` of `newline.length`, although `isEmpty` is `true`.
* **Breaking:** `writeln()` with nothing on the current line adds a blank line, without indentation, instead of being dropped from the output. On an empty buffer it adds one, so `isEmpty` becomes `false` even though `toString()` is still empty.

### Fixes in 6.0.0

* **Copying:** Lines copied with `copyInto` get consecutive line numbers and correct offsets, including when the target buffer is empty or its last line has already been ended.
* **Copying:** The `lastSpan` of a copied line keeps its position within the line, even when the same text appears earlier in the line.
* **Copying:** A buffer can be copied into itself.
* **Copying:** `sourceMappings` are copied with each line, unchanged, instead of being dropped.
* **Copying:** Blank lines are copied without indentation.
* **Writing:** `writeCharCode` counts a character outside the Basic Multilingual Plane, such as an emoji, as two code units.
* **Writing:** `clear()` resets `lastLine`.

## 5.5.0

* Require Dart >= 3.13

## 5.4.0

* Require Dart >= 3.8

## 5.3.0

* Require Dart >= 3.5
* Updated `lints` to 5.0.0

## 5.2.0

* Require Dart >= 3.3
* Updated `lints` to 4.0.0

## 5.1.0

* Updated `lints` to 3.0.0

## 5.0.0

* Require Dart >= 3.0

## 5.0.0-beta.1

* Require Dart >= 3.0

## 4.0.0

* Require Dart >= 2.17

## 3.0.2

* Fixed license link

## 3.0.1

* Updated README

## 3.0.0

* Upgraded from `pendantic` to `lints` linter
* Published as `belatuk_code_buffer` package

## 2.0.3

* Resolved static analysis warnings

## 2.0.2

* Updated README

## 2.0.1

* Fixed invalid homepage url in pubspec.yaml

## 2.0.0

* Migrated to support Dart SDK 2.12.x NNBD

## 1.0.1

* Added `CodeBuffer.noWhitespace()`.
