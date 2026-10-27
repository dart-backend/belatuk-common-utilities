# Change Log

## 7.0.0

### Breaking changes in 7.0.0

* **Breaking:** `RangeHeader.parse` rejects a range that ends before it starts, such as `bytes=10-5`, and text after the last range, such as `bytes=0-10 20`, with a `RangeHeaderParseException`.
* **Breaking:** `RangeHeaderTransformer` writes ranges in order of their position in the input and merges overlapping ones, leaves out ranges that start past the end of the input, and cuts back ranges that end past it.
* **Breaking:** The `RangeHeaderTransformer` constructor throws an `ArgumentError` when none of the ranges can be satisfied, so the server can respond with `416 Range Not Satisfiable`.
* **Breaking:** The `totalFileSize` argument of `computeContentLength` is optional, and it throws an `ArgumentError` if it differs from `totalLength`.
* **Breaking:** `toContentRange` writes `*` for the total size when none is given, and throws when the range's start or end is unknown.

### Fixes in 7.0.0

* **Parsing:** `overlaps` no longer reports disjoint ranges as overlapping, so `bytes=5-10,0-2` stays two ranges, and a range inside another is merged in either order.
* **Parsing:** Merging a range with an open-ended one, such as `bytes=0-600,500-`, keeps the open end.
* **Parsing:** `RangeHeader.parse` honours `fold: false`.
* **Content-Range:** `toContentRange` gives the last bytes of the total for a suffix range, such as `-500`, and cuts an end past the last byte back to it.
* **Transformer:** Each part includes the last byte of its range.
* **Transformer:** A suffix range, such as `bytes=-500`, returns the last bytes of the input, not the first.
* **Transformer:** The `Content-Range` header of each part no longer repeats the total size.
* **Transformer:** `computeContentLength` matches the number of bytes written.
* **Transformer:** An input shorter than `totalLength` fails the output stream and closes it, instead of leaving it open forever, and the input is no longer read after the last range.

## 6.6.0

* Require Dart >= 3.13

## 6.5.0

* Require Dart >= 3.8

## 6.4.0

* Require Dart >= 3.5
* Updated `lints` to 5.0.0

## 6.3.0

* Require Dart >= 3.3
* Updated `lints` to 4.0.0

## 6.2.0

* Updated `lints` to 3.0.0

## 6.1.0

* Updated `file` to 7.0.0

## 6.0.0

* Require Dart >= 3.0
* Updated all dependencies to latest

## 6.0.0-beta.1

* Require Dart >= 3.0

## 5.0.0

* Require Dart >= 2.17

## 4.0.1

* Fixed license link

## 4.0.0

* Upgraded from `pendantic` to `lints` linter
* Published as `belatuk_range_header` package
* Fixed linter warnings

## 3.0.2

* Updated README
  
## 3.0.1

* Resolve static analysis warnings

## 3.0.0

* Migrated to work with Dart SDK 2.12.x NNBD

## 2.0.2

* Fix bug in `toContentRange` that printed invalid indices.
* Fold header items by default.

## 2.0.1

* Adjust `RangeHeaderTransformer` to properly print the content range of each item,
when multiple are present.

## 2.0.0

* Dart 2 update.
* Add `RangeHeaderTransformer`.
* Overall restructuring/refactoring.
