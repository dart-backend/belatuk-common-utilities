# Betaluk Html Builder

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/belatuk_html_builder?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![License](https://img.shields.io/github/license/dart-backend/belatuk-common-utilities)](https://github.com/dart-backend/belatuk-common-utilities/blob/main/packages/html_builder/LICENSE)

A library for building HTML as a tree of Dart objects and rendering it to a string. It can be used as an internal DSL, for example as the basis of a templating engine, and has no dependencies on `dart:io` or `dart:html`.

## Installation

```yaml
dependencies:
  belatuk_html_builder: ^6.0.0
```

The package has two libraries. `package:belatuk_html_builder/belatuk_html_builder.dart` contains the node classes, the renderer and the builder. `package:belatuk_html_builder/elements.dart` exports all of that, and adds a helper function for each HTML5 element.

## Building and rendering a page

```dart
import 'package:belatuk_html_builder/elements.dart';

void main() {
  var dom = html(
    lang: 'en',
    c: [
      head(
        c: [
          title(c: [text('Hello, world!')]),
        ],
      ),
      body(
        c: [
          h1(c: [text('Hello, world!')]),
          p(className: 'intro', c: [text('Ok')]),
        ],
      ),
    ],
  );

  print(StringRenderer().render(dom));
}
```

This prints:

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <title>
      Hello, world!
    </title>
  </head>
  <body>
    <h1>
      Hello, world!
    </h1>
    <p class="intro">
      Ok
    </p>
  </body>
</html>
```

## Nodes

A document is a tree of `Node` objects. Each node has a `tagName`, a map of `attributes` and a list of `children`. Two nodes are equal when they are of the same class and their tag names, attributes and children are equal. Two text nodes are equal when they are of the same class and have the same text.

| Class | Renders as |
| --- | --- |
| `Node` | An element with a closing tag, such as `<div></div>` |
| `SelfClosingNode` | An element without children or a closing tag, such as `<br>` |
| `TextNode` | Its `text`, HTML-escaped |
| `RawNode` | Its HTML, exactly as given, without escaping |

The `h` function is a shorthand for the `Node` constructor. It takes the tag name, then optionally the attributes and the children, as positional arguments. It can create any element, including custom ones.

```dart
var node = h('my-element', {'data-id': 42}, [TextNode('Hello')]);
```

## Escaping and raw HTML

The renderer escapes text and attribute values, so it is safe to put untrusted input in a `text` node or an attribute. Text inside `<script>` and `<style>` elements is written as-is, since browsers do not decode entities there.

To insert HTML that is already built, use `raw`, which creates a `RawNode`. Never pass untrusted input to `raw`.

```dart
var renderer = StringRenderer(pretty: false, doctype: '');

var comment = '<script>alert("Hi")</script>';
print(renderer.render(p(c: [text(comment)])));
// <p>&lt;script&gt;alert("Hi")&lt;/script&gt;</p>

print(renderer.render(p(c: [raw('<b>Bold</b>')])));
// <p><b>Bold</b></p>
```

## Attribute values

An attribute value does not have to be a string. The renderer converts it as follows, then escapes it:

| Value | Rendered as |
| --- | --- |
| `true` | The attribute name only, such as `disabled` |
| `false` or `null` | Nothing. The attribute is left out |
| An `Iterable` | The items joined with spaces, such as `class="a b"` |
| A `Map` | Each entry as `key: value;`, such as `style="color: red;margin: 0;"` |
| Anything else | Its `toString()`, such as `width="100"` |

```dart
var renderer = StringRenderer(pretty: false, doctype: '');

var node = h('button', {
  'class': ['btn', 'wide'],
  'style': {'color': 'red', 'margin': 0},
  'disabled': true,
  'hidden': false,
  'title': null,
});

print(renderer.render(node));
// <button class="btn wide" style="color: red;margin: 0;" disabled></button>
```

## HTML5 element helpers

`package:belatuk_html_builder/elements.dart` has a function for each standard HTML5 element, from `a` to `wbr`, plus `text` for a text node and `raw` for raw HTML. The function for `<var>` is called `var_`, because `var` is a reserved word in Dart.

Each function takes named arguments:

| Argument | Meaning |
| --- | --- |
| `id`, `className`, `style` | The `id`, `class` and `style` attributes. `className` and `style` can be any of the attribute values above |
| Element-specific attributes | For example `href` and `target` on `a`, or `src`, `alt` and `width` on `img` |
| `p` | Any other attributes, as a map. These replace named arguments for the same attribute |
| `c` | The children. Not available on self-closing elements |

```dart
var renderer = StringRenderer(pretty: false, doctype: '');

var link = a(
  href: '/docs',
  className: ['nav', 'active'],
  p: {'data-section': 'docs'},
  c: [text('Documentation')],
);

print(renderer.render(link));
// <a href="/docs" class="nav active" data-section="docs">Documentation</a>
```

`area`, `base`, `col`, `embed`, `img`, `input`, `keygen`, `link`, `meta`, `param`, `source`, `track` and `wbr` create a `SelfClosingNode`. `br()` and `hr()` also do, and take no arguments.

## Rendering options

`StringRenderer` renders a node and its descendants to a `String`. Its constructor takes these named arguments:

| Argument | Default | Effect |
| --- | --- | --- |
| `pretty` | `true` | Puts each node, including each text node, on its own line, indented by its depth |
| `whitespace` | `'  '` | The indentation for each level when `pretty` is `true` |
| `doctype` | `'html'` | Writes `<!DOCTYPE html>` before the node. Pass an empty string to leave it out, for example when rendering part of a page |
| `html5` | `true` | Renders self-closing elements as `<br>`. Pass `false` to render them as `<br/>` |

```dart
var renderer = StringRenderer(pretty: false, doctype: '', html5: false);

print(renderer.render(div(c: [text('One'), br(), text('Two')])));
// <div>One<br/>Two</div>
```

`StringRenderer` implements `Renderer<String>`. Implement `Renderer<T>` to render a node tree into another representation.

## Changing nodes

Nodes are mutable, but `NodeBuilder` offers a way to make modified copies. `NodeBuilder.from` creates a builder from an existing node, each `change`, `set`, `add`, `remove` and `toggle` method returns a new builder, and `build` creates the node.

```dart
var renderer = StringRenderer(pretty: false, doctype: '');
var button = h('button', {'class': 'btn'}, [text('Save')]);

var primary = NodeBuilder.from(button)
    .addClass('primary')
    .setId('save')
    .setAttribute('type', 'submit')
    .build();

print(renderer.render(primary));
// <button class="btn primary" id="save" type="submit">Save</button>
```

| Method | Effect |
| --- | --- |
| `setId`, `setClassName`, `setClasses` | Set the `id` or `class` attribute |
| `addClass`, `removeClass`, `toggleClass` | Change one class in the `class` attribute |
| `setAttribute`, `removeAttribute` | Set or remove one attribute |
| `addChild`, `removeChild` | Add or remove one child |
| `changeTagName`, `changeAttributes`, `changeChildren` | Replace the tag name, all attributes or all children |
| `mapAttributes`, `mapChildren` | Transform each attribute or child |

`rebuild` turns a builder transformation into a function on nodes, which is convenient for reusing a change. A builder made with `NodeBuilder.from` keeps whether the node is self-closing, and `rebuild` returns text nodes unchanged. Pass `selfClosing` to `rebuild` or `build` to choose explicitly.

```dart
var renderer = StringRenderer(pretty: false, doctype: '');
var highlight = rebuild((b) => b.addClass('highlight'));

print(renderer.render(highlight(p(c: [text('Note')]))));
// <p class="highlight">Note</p>
```

`rebuildRecursive` applies a function to a node and all its descendants:

```dart
var renderer = StringRenderer(pretty: false, doctype: '');
var highlightAll = rebuildRecursive(rebuild((b) => b.addClass('hl')));

print(renderer.render(highlightAll(p(c: [text('One'), br()]))));
// <p class="hl">One<br class="hl"></p>
```

## Limitations

When `pretty` is `true`, the whitespace added around text nodes becomes part of the text. Render with `pretty: false` where whitespace matters, as in `<pre>` and `<textarea>`.

Text inside `<script>` and `<style>` is not escaped, so never put untrusted input there: a `</script>` in it ends the script element. Tag and attribute names are not checked or escaped either.

## Upgrading from 5.x

Version 6.0.0 escapes text and attribute values, so code that put HTML in a `text` node must use `raw` instead, and code that escaped values itself must stop, or they will be escaped twice. `col`, `keygen` and `wbr` are now self-closing and no longer take children, and `iframe` now takes children. See the [changelog](CHANGELOG.md) for the full list.
