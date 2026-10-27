# Belatuk Symbol Table

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/belatuk_symbol_table?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![License](https://img.shields.io/github/license/dart-backend/belatuk-common-utilities)](https://github.com/dart-backend/belatuk-common-utilities/blob/main/packages/symbol_table/LICENSE)

A generic symbol table for interpreters and compilers written in Dart, with support for nested scopes, constants, visibility and closures. Symbol tables form a tree of scopes, and cache lookups to speed up repeated ones.

## Installation

```yaml
dependencies:
  belatuk_symbol_table: ^6.0.0
```

## Symbol tables and variables

A `SymbolTable<T>` holds variables whose values are of type `T`. A symbol is represented by a `Variable`, a name chosen to avoid clashing with Dart's own `Symbol` class. Variables are created through a symbol table, never directly.

```dart
var scope = SymbolTable<double>(values: {'hydrogen': 1.0, 'avogadro': 6.022e23});

// Create a variable in this scope. Creating a second variable with the same
// name in the same scope throws a StateError.
scope.create('one', value: 1.0);
scope.create('pi', value: 3.14159, constant: true);

// Set the value of a variable in this scope or an ancestor, or create one in
// this scope if none exists.
scope.assign('two', 2.0);
scope['three'] = 3.0; // The same as assign.

// Find a variable in this scope or an ancestor. Returns null if there is none.
var one = scope.resolve('one');
var alsoOne = scope['one']; // The same as resolve.

// Find a variable, or create one if there is none.
var four = scope.resolveOrCreate('four', value: 4.0);

// Remove a variable from this scope or an ancestor.
scope.remove('two');
```

## Constants

A constant's value cannot be changed. Create one with `constant: true`, or call `lock` on an existing variable.

```dart
var scope = SymbolTable<String>();
var name = scope.create('name', value: 'Mary');
name.lock();

print(name.isImmutable); // true
name.value = 'Shelley'; // Throws a StateError.
```

## Visibility

Variables are *public* by default, but can also be marked as *protected* or *private*. The package gives these no meaning of its own: use them to decide which symbols to export from a library or class. Visibilities can be compared, with `private < protected < public`.

```dart
var scope = SymbolTable<int>();
scope.create('helper').visibility = Visibility.private;
```

## Exporting symbols

`allVariables` lists every variable visible from a scope. When a scope and an ancestor both have a variable with the same name, only the nearer one is listed, as with variable shadowing.

```dart
var global = SymbolTable<int>(values: {'x': 1, 'y': 2});
var local = global.createChild(values: {'x': 10});

print(local.allVariables.map((v) => '${v.name}=${v.value}')); // (x=10, y=2)
```

`allPublicVariables` lists only the public ones, and `allVariablesWithVisibility` lists those with a given visibility. A shadowed variable is never listed, even when the variable shadowing it has a different visibility.

```dart
var global = SymbolTable<int>(values: {'x': 1, 'y': 2});
var local = global.createChild();
local.create('x').visibility = Visibility.private;

print(local.allPublicVariables.map((v) => v.name)); // (y)
print(local.allVariablesWithVisibility(Visibility.private).length); // 1
```

## Scopes

There are three ways to create a new scope from an existing one.

### Child scopes

This is what most interpreters need. `createChild` creates a scope whose parent is the current one. The child can see its ancestors' variables, and its own variables shadow theirs.

```dart
var global = SymbolTable<int>(values: {'x': 1});
var block = global.createChild(values: {'y': 2});

print(block.resolve('x')?.value); // 1
print(block.depth); // 1
```

Every scope has a `depth`, which is `0` at the root and one more for each level of children. `parent`, `root` and `isRoot` describe a scope's place in the tree.

### Clones

`clone` creates a scope at the same level as the current one, with the same parent and copies of its variables. Changing a variable in the clone does not change the original, and the other way around. The clone starts with no children of its own.

```dart
var scope = SymbolTable<int>(values: {'x': 1});
var clone = scope.clone();
clone.assign('x', 2);

print(scope.resolve('x')?.value); // 1
```

### Forked scopes

`fork` is useful for closures. Like a clone, a fork has copies of the current scope's variables, so their values are captured at the moment the fork is made. You can pass starter `values`, which replace copied variables with the same names.

A fork has the same parent as the current scope, but the parent does not know about it. A fork looks up its ancestors' variables each time, so it sees variables that are added to or removed from them later.

```dart
var scope = SymbolTable<int>(values: {'counter': 0});
var closure = scope.fork(values: {'step': 1});

scope.assign('counter', 5);
print(closure.resolve('counter')?.value); // 0
```

## Unique names

In languages with block scope, identifiers from different blocks can collide once they are combined into one scope. `uniqueName` adds a numerical suffix to a name, and never returns the same name twice within a scope.

```dart
var scope = SymbolTable<int>();
print(scope.uniqueName('foo')); // foo0
print(scope.uniqueName('foo')); // foo1
```

A name is not reused by the scope, its ancestors or its descendants, and is never the name of a variable visible from the scope. Sibling scopes, which cannot see each other's names, may generate the same name.

## The `this` context

Many languages resolve some values against a `this` context. A scope can set a `context`, and a scope without one uses its nearest ancestor's.

```dart
var classScope = SymbolTable<Object>()..context = 'instance';
var methodScope = classScope.createChild().createChild();

print(methodScope.context); // instance
```

## Upgrading from 5.x

Version 6.0.0 corrects several behaviours. Most notably, `clone` now copies variables instead of sharing them, and `uniqueName` may return different names. See the [changelog](CHANGELOG.md) for the full list.
