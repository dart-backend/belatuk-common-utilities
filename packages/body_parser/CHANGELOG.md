# Change Log

## 6.0.0

### Breaking changes in 6.0.0

* **Breaking:** Requires `belatuk_http_server` 5.0.0. Projects that still depend on `belatuk_http_server` 4.x cannot use this version.
* **Breaking:** A multipart text field's value is stored exactly as sent. Before, it was split on `&` and `=` and URL-decoded, so code that relied on `+` turning into a space or `%XX` being decoded will see different values.

### Fixes in 6.0.0

* **Multipart:** A field value containing `&` and `=` can no longer add extra fields to the body, and a value containing `%` no longer makes the whole parse fail.
* **Multipart:** An uploaded file without a `Content-Type` header keeps its original bytes, instead of having non-ASCII characters corrupted.
* **Multipart:** An uploaded file without a `Content-Type` header is given the MIME type `text/plain`, instead of throwing a null-check error that discarded every field and file in the request.

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
