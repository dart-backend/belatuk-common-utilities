# Belatuk Body Parser

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/belatuk_body_parser?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![License](https://img.shields.io/github/license/dart-backend/belatuk-common-utilities)](https://github.com/dart-backend/belatuk-common-utilities/blob/main/packages/body_parser/LICENSE)

**Replacement of `package:body_parser` with breaking changes to support NNBD.**

Parse request bodies and query strings in Dart, as well multipart/form-data uploads. No external dependencies required.

This is the request body parser powering the [Angel3 framework](https://pub.dev/packages/angel3_framework). If you are looking for a server-side solution with dependency injection, WebSockets, and more, then I highly recommend it as your first choice. Bam!

## Contents

- [Belatuk Body Parser](#belatuk-body-parser)
  - [Contents](#contents)
    - [About](#about)
    - [Installation](#installation)
    - [Usage](#usage)
    - [Custom Body Parsing](#custom-body-parsing)

### About

I needed something like Express.js's `body-parser` module, so I made it here. It fully supports JSON requests. x-www-form-urlencoded fully supported, as well as query strings. You can also include arrays in your query, in the same way you would for a PHP application. Full file upload support will also be present by the production 1.0.0 release.

A benefit of this is that primitive types are automatically deserialized correctly. As in, if you have a `hello=1.5` request, then `body['hello']` will equal `1.5` and not `'1.5'`. A very semantic difference, yes, but it relieves stress in my head.

### Installation

To install Body Parser for your Dart project, simply add body_parser to your pub dependencies.

  dependencies:
      belatuk_body_parser: ^4.0.0

### Usage

Body Parser exposes a simple class called `BodyParseResult`. You can easily parse the query string and request body for a request by calling `Future<BodyParseResult> parseBody`.

  ```dart
  import 'dart:convert';
  import 'package:belatuk_body_parser/belatuk_body_parser.dart';

  main() async {
    // ...
    await for (HttpRequest request in server) {
      request.response.write(JSON.encode(await parseBody(request).body));
      await request.response.close();
    }
  }
  ```

You can also use `buildMapFromUri(Map, String)` to populate a map from a URL encoded string.

This can easily be used with a library like [Angel3 JSON God](https://pub.dev/packages/angel3_json_god) to build structured JSON/REST APIs. Add validation and you've got an instant backend.

  ```dart
  MyClass create(HttpRequest request) async {
      return god.deserialize(await parseBody(request).body, MyClass);
  }
  ```

### Custom Body Parsing

In cases where you need to parse unrecognized content types, `body_parser` won't be of any help to you on its own. However, you can use the `originalBuffer` property of a `BodyParseResult` to see the original request buffer. To get this functionality, pass `storeOriginalBuffer` as `true` when calling `parseBody`.

For example, if you wanted to [parse GraphQL queries within your server](https://github.com/dukefirehawk/graphql_dart)...

  ```dart
  app.get('/graphql', (req, res) async {
    if (req.headers.contentType.mimeType == 'application/graphql') {
      var graphQlString = String.fromCharCodes(req.originalBuffer);
      // ...
    }
  });
  ```
