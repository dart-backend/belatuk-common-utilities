# Betaluk Html Builder

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/belatuk_html_builder?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![License](https://img.shields.io/github/license/dart-backend/belatuk-common-utilities)](https://github.com/dart-backend/belatuk-common-utilities/blob/main/packages/html_builder/LICENSE)

**Replacement of `package:html_builder` with breaking changes to support NNBD.**

This package builds HTML AST's and renders them to HTML. It can be used as an internal DSL, i.e. for a templating engine.

## Requirements

* Dart SDK: 3.0.x or later

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  belatuk_html_builder: ^5.0.0
```

## Usage

```dart
import 'package:belatuk_html_builder/belatuk_html_builder.dart';

void main() {
    // Akin to React.createElement(...);
    var $el = h('my-element', p: {}, c: []);

    // Attributes can be plain Strings.
    h('foo', p: {
        'bar': 'baz'
    });

    // Null attributes do not appear.
    h('foo', p: {
        'does-not-appear': null
    });

    // If an attribute is a bool, then it will only appear if its value is true.
    h('foo', p: {
        'appears': true,
        'does-not-appear': false
    });

    // Or, a String or Map.
    h('foo', p: {
        'style': 'background-color: white; color: red;'
    });

    h('foo', p: {
        'style': {
            'background-color': 'white',
            'color': 'red'
        }
    });

    // Or, a String or Iterable.
    h('foo', p: {
        'class': 'a b'
    });

    h('foo', p: {
        'class': ['a', 'b']
    });
}
```

Standard HTML5 elements:

```dart
import 'package:belatuk_html_builder/elements.dart';

void main() {
    var $dom = html(lang: 'en', c: [
        head(c: [
            title(c: [text('Hello, world!')])
        ]),
        body(c: [
            h1(c: [text('Hello, world!')]),
            p(c: [text('Ok')])
        ])
    ]);
}
```

Rendering to HTML:

```dart
String html = StringRenderer().render($dom);
```

Example implementation with the [Angel3](https://pub.dev/packages/angel3_framework) backend framework,
which uses [dedicated html_builder package](https://github.com/dukefirehawk/angel/tree/html):

```dart
import 'dart:io';
import 'package:belatuk_framework/belatuk_framework.dart';
import 'package:belatuk_html_builder/elements.dart';

configureViews(Angel app) async {
    app.get('/foo/:id', (req, res) async {
        var foo = await app.service('foo').read(req.params['id']);
        return html(c: [
            head(c: [
                title(c: [text(foo.name)])
            ]),
            body(c: [
                h1(c: [text(foo.name)])
            ])
        ]);
    });
}
```
