# Change Log

## 6.0.0

### Breaking changes in 6.0.0

* **Breaking:** Requires `belatuk_code_buffer` 6.0.0, which `Parser.stringify` takes. Its `length`, span offsets and `writeln()` behave differently, as described in its changelog.
* **Breaking:** `Reference.printed` is removed. Each `CodeBuffer` now tracks which references it has printed.

### Fixes in 6.0.0

* **Stringify:** A reference is printed in full the first time, and `(previously printed reference)` is only written when it appears again.
* **Stringify:** Calling `stringify` again with a new `CodeBuffer` prints references in full, instead of only the marker.
* **Stringify:** A reference that contains itself no longer recurses forever.

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
* Fixed lints warnings

## 5.0.0

* Require Dart >= 3.0
  
## 5.0.0-beta.1

* Require Dart >= 3.0
* Updated `belatuk_code_buffer` to 5.0.0

## 4.0.0

* Require Dart >= 2.17

## 3.0.1

* Fixed license link

## 3.0.0

* Upgraded from `pendantic` to `lints` linter
* Published as `belatuk_combinator` package
* Resolved static analysis warnings

## 2.0.2

* Resolved static analysis warnings

## 2.0.1

* Updated README

## 2.0.0

* Migrated to support Dart SDK 2.12.x NNBD

## 1.1.0

* Add `tupleX` parsers. Hooray for strong typing!

## 1.0.0+3

* `then` now *always* returns `dynamic`.

## 1.0.0+2

* `star` now includes with a call to `opt`.
* Added comments.
* Enforce generics on `separatedBy`.
* Enforce Dart 2 semantics.
