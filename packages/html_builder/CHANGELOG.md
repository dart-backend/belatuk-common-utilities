# Change Log

## 6.0.0

### Breaking changes in 6.0.0

* **Breaking:** Text and attribute values are HTML-escaped when rendered, except text inside `<script>` and `<style>`. Use `raw` for HTML that must be written as-is, and stop escaping values yourself, or they will be escaped twice.
* **Breaking:** `col`, `keygen` and `wbr` create self-closing nodes and no longer take children, and `iframe` creates a node with a closing tag and takes children.
* **Breaking:** Nodes of different classes are never equal, so `Node('br')` no longer equals `SelfClosingNode('br')`, and `TextNode` equality is symmetric.
* **Breaking:** `NodeBuilder.build` and `rebuild` take a nullable `selfClosing`. When it is omitted, a builder made with `NodeBuilder.from` keeps whether the node was self-closing, instead of always creating a `Node`.

### New in 6.0.0

* Added `RawNode` and the `raw` helper, for HTML that is rendered without escaping.
* Added the `data`, `hgroup`, `meter`, `search`, `slot` and `template` helpers.

### Fixes in 6.0.0

* **Elements:** `abbr` renders `<abbr>` instead of `<addr>`.
* **Elements:** `article` takes `id`, and its `className` and `style` accept any attribute value, like the other helpers.
* **Builder:** `addClass` no longer adds a class that is already present.
* **Builder:** `rebuild` and `rebuildRecursive` keep text nodes and self-closing nodes, instead of turning them into empty elements.
* **Nodes:** Equal nodes have equal hash codes, whatever the order of their attributes.
* **Docs:** The `html5` option of `StringRenderer` is described correctly: `true` renders `<br>`, and `false` renders `<br/>`.
* **Docs:** The example prints the rendered HTML instead of `Instance of 'Node'`.

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
* Added hashCode

## 3.0.2

* Fixed license link

## 3.0.1

* Update broken link in pubspec

## 3.0.0

* Upgraded from `pendantic` to `lints` linter
* Removed deprecated parameters
* Published as `belatuk_html_builder` package

## 2.0.3

* Added an example
* Updated README

## 2.0.2

* Run `dartfmt -w .`

## 2.0.1

* Added pedantic dart rules

## 2.0.0

* Migrated to work with Dart SDK 2.12.x NNBD

## 1.0.4

* Added `rebuild`, `rebuildRecursive`, and `NodeBuilder`.

## 1.0.3

* Dart 2 ready!

## 1.0.2

* Changed `h` and the `Node` constructor to take `Iterable`s of children, instead of just `List`s.
