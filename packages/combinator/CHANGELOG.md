# Change Log

## 6.0.0

### Breaking changes in 6.0.0

* **Breaking:** Requires `belatuk_code_buffer` 6.0.0, which `Parser.stringify` takes. Its `length`, span offsets and `writeln()` behave differently, as described in its changelog.
* **Breaking:** `chain`, `then` and the `tupleN` functions give `null` for an element without a value, instead of the string `'NULL'`. A `chain` with a non-nullable type, such as `chain<String>`, throws a `StateError` when an element has no value, so use a nullable type, such as `chain<String?>`, when that can happen.
* **Breaking:** `star()` gives an empty list when nothing matches, instead of `null`.
* **Breaking:** Left-recursive rules, such as `sum := sum '+' number | number`, parse all of their input and group from the left, instead of stopping after one step, so `1+2+3` is no longer parsed as `1+2`. A grammar that was left-recursive by accident, and relied on that rule failing, can now parse differently. `any` and `longest` no longer skip an alternative that is already being parsed at the same position; it fails there instead, as before.
* **Breaking:** `stringify` numbers each reference, printing it as `reference #1 (...)` the first time and as `reference #1 (printed above)` after that, instead of writing `(previously printed reference)`.
* **Breaking:** `cache()` returns the parser itself, instead of a new parser that `stringify` prints as `cache (...)`. Every parser's results are already cached for one parse, so parsing new text with a cached parser no longer returns earlier results, and a cached part of a left-recursive rule still grows.
* **Breaking:** `Reference.printed` is removed. Each call to `stringify` tracks the references it has printed.

### Fixes in 6.0.0

* **Parsing:** A memoized result moves the scanner to where the original parse ended, so alternatives that start with the same parser, such as `any([chain([a, b]), chain([a, c])])`, parse correctly.
* **Parsing:** `separatedByComma()` no longer throws a `TypeError` when it matches a comma.
* **Parsing:** `surroundedByCurlyBraces` and `surroundedBySquareBrackets` give `defaultValue` for empty braces or brackets, instead of throwing a `TypeError`.
* **Parsing:** `&` and `|` accept a parser of any type, so they no longer throw a `TypeError` at run time when the two parsers' types differ. `|` casts the other parser's values to this parser's type.
* **Parsing:** `opt(backtrack: false)` keeps the text consumed by a failed attempt, as documented, instead of always backtracking, and includes that text in its span. `opt` gives no span when the failed attempt consumed nothing.
* **Parsing:** `chain` with `failFast: false` no longer throws a `StateError` for an element without a value once an element has failed. With a non-nullable type, the failed result then has no value. With a nullable type, it keeps the partial list of values, as before.
* **Parsing:** Left-recursive rules reached while another rule is growing at the same position, including mutually left-recursive rules, also grow, so they parse all of their input.
* **Parsing:** A result added with `Trampoline.memoize` moves the scanner to the end of its span when it is used again, like a result memoized during parsing.
* **Performance:** Memoized results are stored by position, so looking one up, and forgetting a position while a left-recursive rule grows, no longer scans every parser's results.
* **Stringify:** Each call to `stringify` prints references in full again, even into a buffer that was used before or cleared.
* **Stringify:** A reference that contains itself no longer recurses forever.
* **Examples:** The `json`, `main`, `calculator`, `basic_auth` and `sexp` examples run, and every interactive example stops at the end of its input instead of crashing.

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
