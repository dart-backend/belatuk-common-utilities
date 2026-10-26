# Change Log

## 6.0.0

### Breaking changes in 6.0.0

* **Breaking:** `clone()` copies the scope's variables, so changing a variable in the clone no longer changes the original, and each copy's `symbolTable` is the clone.
* **Breaking:** A variable copied into a fork has the fork as its `symbolTable`, instead of the original scope.
* **Breaking:** `uniqueName` no longer returns a name that a descendant scope has generated, or the name of a visible variable, so some generated names change.
* **Breaking:** `allVariablesWithVisibility` and `allPublicVariables` leave out a variable that a variable in a nearer scope shadows, even when the two have different visibilities.

### Fixes in 6.0.0

* **Forks:** `fork()` uses its `values`, which replace copied variables with the same names.
* **Forks:** A fork resolves variables from its ancestors afresh each time, so it no longer returns one that was removed, or that a newer variable shadows.
* **Forks:** `fork()` and `clone()` keep the scope's `context` and the names it has generated with `uniqueName`.
* **Docs:** The `remove()` documentation describes how forks behave, and no longer refers to a missing `createdChild` method.

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

## 4.0.0

* Require Dart >= 2.17

## 3.0.1

* Fixed license link

## 3.0.0

* Upgraded from `pendantic` to `lints` linter
* Published as `belatuk_symbol_table` package
* Fixed linter warnings

## 2.0.2

* Resolved static analysis warnings

## 2.0.1

* Resolved static analysis warnings

## 2.0.0

* Migrated to work with Dart SDK 2.12.x NNBD

## 1.0.4

* Added `context` to `SymbolTable`.

## 1.0.3

* Converted `Visibility` into a `Comparable` class.
* Renamed `add` -> `create`,  `put` -> `assign`, and `allVariablesOfVisibility` -> `allVariablesWithVisibility`.
* Added tests for `Visibility` comparing, and `depth`.
* Added `uniqueName()` to `SymbolTable`.
* Fixed a typo in `remove` that would have prevented it from working correctly.

## 1.0.2

* Added `depth` to `SymbolTable`.
* Added `symbolTable` to `Variable`.
* Deprecated the redundant `Constant` class.
* Deprecated `Variable.markAsPrivate()`.
* Added the `Visibility` enumerator.
* Added the field `visibility` to `Variable`.
