# Change Log

## 6.0.0

### Breaking changes in 6.0.0

* **Breaking:** Nested maps are merged even when their key or value types differ from the outer map's, as long as the merged map fits the value type. Before, such maps overwrote each other. When the types differ, the merged map is a `Map<dynamic, dynamic>`.
* **Breaking:** Nested maps more than one level deep keep the outer key and value types when they fit them, such as `Map<String, dynamic>`, instead of becoming `Map<dynamic, dynamic>`.

### Fixes in 6.0.0

* **Merging:** Merging nested maps no longer relies on an unchecked cast, which could throw a `TypeError`.
* **Docs:** The README example passes the maps as a list, as `mergeMap` expects.

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
* Published as `belatuk_merge_map` package
* Fixed linter warnings

## 2.0.2

* Resolve static analysis warnings

## 2.0.1

* Updated README

## 2.0.0

* Migrated to work with Dart SDK 2.12.x NNBD

## 1.0.2

* Add an example, for Pub's sake.

## 1.0.1

* Add a specific constraint on Dart versions, to prevent Pub from rejecting all packages that depend on
`merge_map` (the entire Angel framework).
* Add generic type support
