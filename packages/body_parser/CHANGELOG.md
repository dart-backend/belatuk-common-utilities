# Change Log

## 6.0.0

### Breaking changes in 6.0.0

* **Breaking:** Multipart text fields are no longer URL-decoded or split on `&` and `=`, so `+` and `%XX` are kept as sent.
* **Breaking:** Only UTF-8 and US-ASCII text is accepted. Any other declared charset, or bytes that are not valid for the charset, fail the parse with a `FormatException`. Before, a multipart text field was decoded with its declared charset, and the charset of a JSON or URL-encoded body was ignored.
* **Breaking:** Conflicting keys, such as `user` with `user.name` or `tags` with `tags[]`, fail the parse with a `FormatException`. A repeated plain key still keeps the last value, and a JSON value counts as a plain value, so `a={"x":1}` with `a.y` is a conflict.
* **Breaking:** The query string is parsed for every request, and an error in it fails the request without parsing the body.
* **Breaking:** Only plain decimals that convert exactly become numbers, such as `42`, `-7` or `14.5`. Values such as `01234`, `+1555`, `1e3`, `0x1F` and `Infinity` stay strings, as do integers too large for an `int` and decimals with more than 15 significant digits or outside the range of a double. `-0` and `-0.0` lose their sign.
* **Breaking:** A dotted list key such as `user.tags[]` is nested, giving `user: {tags: [...]}`.
* **Breaking:** A key without `=` follows the same rules as other keys, so `?opts.debug` gives `opts: {debug: true}`.
* **Breaking:** A multipart text field without a `name` is dropped.
* **Breaking:** When the parse fails, `body` and `files` are empty instead of holding whatever was parsed before the error.

### New in 6.0.0

* No longer depends on `belatuk_http_server`.

### Fixes in 6.0.0

* **Multipart:** Uploaded files are stored byte for byte, and a file without a `Content-Type` gets `text/plain` instead of failing the parse.
* **Multipart:** A body cut off part-way fails the parse instead of hanging forever.
* **Multipart:** A field value containing `&`, `=` or `%` no longer adds fields or fails the parse.
* **URL-encoded:** A stray `%` or a raw non-ASCII character is kept instead of failing the parse.
* **URL-encoded:** Empty pairs, as in `/path?` or `a=1&&b=2&`, are skipped instead of stored as `"": true`.
* **Query:** The query string is parsed even when the request has a body.
* **JSON:** A body that is not an object, such as `null` or `[]`, fails with a `FormatException`.
* **Body:** When a bad query string fails a JSON, URL-encoded or multipart request, or a multipart part has bad headers or content, the rest of the body is still read, so it does not stall the connection. A multipart body that is broken, such as one with a bad boundary or cut off part-way, stops the parse, and the rest of it is not read.
* **Values:** Text that only looks like JSON, such as `[draft]`, stays a string instead of failing the parse.

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
