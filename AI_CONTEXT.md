# AI Context: Belatuk Common Utilities

## Project Overview

`belatuk-common-utilities` is a **Dart monorepo** containing a collection of common utility packages required for developing backend framework in Dart.

## Monorepo Architecture

The repository uses [Melos](https://melos.invertase.dev/) and **Dart Workspaces** (requiring Dart SDK `>=3.11.0 <4.0.0`) to manage its multiple packages.

- **`melos.yaml`**: Configures the workspace for Melos scripting and management.
- **`pubspec.yaml`**: Defined as a `workspace` root, listing all internal packages so they resolve locally.

## Available Packages

The repository contains **11 separate packages** located under the `/packages/` directory:

1. **`body_parser`**: Parses HTTP request bodies and query strings. Supports JSON, URL-encoded, and multi-part bodies.
2. **`code_buffer`**: Utilities for efficient string building and code generation.
3. **`combinator`**: Parser combinator tools.
4. **`html_builder`**: Tools for constructing and templating HTML dynamically in Dart.
5. **`json_serializer`**: Utilities for serializing and deserializing JSON data.
6. **`merge_map`**: Utilities for merging Dart `Map` objects.
7. **`pretty_logging`**: Standalone helper for colorful logging output using AnsiCode, built on top of the standard `logging` package.
8. **`pub_sub`**: Utilities for implementing the Publish-Subscribe messaging pattern.
9. **`range_header`**: Parsers and handlers for HTTP `Range` headers.
10. **`symbol_table`**: Implementation of symbol tables used in parsing or compilation tasks.
11. **`user_agent`**: Utilities for parsing and interpreting HTTP User-Agent strings.

## Key Dependencies

These packages typically depend on Dart server-side libraries such as `belatuk_http_server`, `http_parser`, and `mime`. The project enforces code quality and formatting through `test` and standard `lints`.
