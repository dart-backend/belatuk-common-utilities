# Change Log

## 6.0.0

### Breaking changes in 6.0.0

* **Breaking:** A multipart text field's value is no longer split on `&` and `=` or URL-decoded, so `+` stays a `+` and `%XX` is not decoded. Values are still converted the same way as URL-encoded values: numbers become `num`, `null` becomes `null`, and JSON arrays and objects are decoded.
* **Breaking:** Only UTF-8 is accepted for text. A JSON or URL-encoded body, or a multipart text field, whose `Content-Type` declares a charset other than UTF-8 or US-ASCII fails the parse with a `FormatException`, as does text or a percent-escape that is not valid UTF-8. Before, a multipart text field was decoded with its declared charset, and the `charset` of a JSON or URL-encoded body was ignored.
* **Breaking:** Keys that conflict fail the parse with a `FormatException`, instead of one value silently replacing the other. Examples are `user.name` with `user`, `tags[]` with `tags`, and `a.b` with `a.b.c`, in either order. A repeated plain key such as `a=1&a=2` still keeps the last value.
* **Breaking:** The query string is parsed for every request (see below), and an error in it fails the whole request: `error` is set and the body is not parsed.
* **Breaking:** A key without `=`, such as `?debug`, follows the same rules as other keys, so `flags[]` gives `flags: [true]` and `opts.debug` gives `opts: {debug: true}`.
* **Breaking:** A value becomes a number only when it is a plain decimal that converts exactly: an optional `-`, no leading zeros, and an optional fraction, such as `42`, `-7` or `14.5`. Anything else stays a string, including `01234`, `+15551234567`, `1e3`, `0x1F`, numbers with surrounding spaces, `Infinity`, integers too large for an `int`, and decimals with more than 15 significant digits. Before, `num.parse` converted all of these, so leading zeros and precision were lost.
* **Breaking:** A dotted key ending in `[]`, such as `user.tags[]`, appends to a list inside the nested map, giving `user: {tags: [...]}`. Before, it was stored under the literal key `"user.tags"`.
* **Breaking:** A multipart text field without a `name` is dropped, instead of being stored under the key `"null"`.

### Fixes in 6.0.0

* **Multipart:** A field value containing `&` and `=` can no longer add extra fields to the body, and a value containing `%` no longer makes the whole parse fail.
* **Multipart:** An uploaded file's bytes are stored exactly as sent. Before, files sent as text or without a `Content-Type` were decoded as text first, so non-ASCII characters were corrupted, a byte-order mark was dropped, and bytes that were not valid UTF-8 made the whole parse fail.
* **Multipart:** An uploaded file without a `Content-Type` header is given the MIME type `text/plain`, instead of throwing a null-check error that discarded every field and file in the request.
* **URL-encoded:** A `%` that does not start an escape, as in `discount=100%`, is kept as is in URL-encoded bodies and query strings, instead of making the whole parse fail. Raw non-ASCII characters, as in `name=café`, are also kept instead of failing the parse.
* **Query:** The query string is parsed into `query` for every request. Before, it was only parsed when the request had no `Content-Type`, so a request with a JSON, URL-encoded or multipart body always got an empty `query`.
* **Query and URL-encoded:** An empty pair, from an empty query (`/path?`), a trailing `&` or `&&`, is skipped instead of being stored as `"": true`.
* **Values:** A value that starts and ends with brackets or braces but is not valid JSON, such as `[draft]`, is kept as a string instead of making the whole parse fail. This applies to URL-encoded bodies and query strings as well as multipart fields.

### Other changes in 6.0.0

* No longer depends on `belatuk_http_server`. Multipart part headers are read directly.

## 5.6.0

* Require Dart >= 3.13

## 5.5.0

* Require Dart >= 3.8

## 5.4.1

* Updated `mime` to 2.0.0

## 5.4.0

* Require Dart >= 3.5
* Updated `lints` to 5.0.0

## 5.3.0

* Require Dart >= 3.3
* Updated `belatuk_http_server` to 4.4.0
* Updated `lints` to 4.0.0

## 5.2.0

* Updated `lints` to 3.0.0
* Updated `belatuk_http_server` to 4.2.0

## 5.1.0

* Updated `belatuk_http_server` to 4.1.1
* Updated `http` to 1.0.0

## 5.0.0

* Require Dart >= 3.0

## 5.0.0-beta.1

* Require Dart >= 3.0
* Updated `belatuk_http_server` to 4.0.0

## 4.0.1

* Updated `belatuk_http_server` to 3.0.0

## 4.0.0

* Require Dart >= 2.17

## 3.0.1

* Fixed boken license link

## 3.0.0

* Upgraded from `pendantic` to `lints` linter
* Published as `belatuk_body_parser` package
* Fixed linter warnings

## 2.1.1

* Fixed calling deprecated methods in unit test

## 2.1.0

* Replaced `http_server` with `belatuk_http_server`

## 2.0.1

* Fixed source code formating warning
* Updated README

## 2.0.0

* Migrated to support Dart SDK 2.12.x NNBD

## 1.1.1

* Dart 2 updates; should fix Angel in Travis.

## 1.1.0

* Add `parseBodyFromStream`
