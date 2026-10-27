import 'package:collection/collection.dart';

/// Shorthand function to generate a new [Node].
Node h(
  String tagName, [
  Map<String, dynamic> attributes = const {},
  Iterable<Node> children = const [],
]) => Node(tagName, attributes, children);

/// Represents an HTML node.
class Node {
  final String tagName;
  final Map<String, dynamic> attributes = {};
  final List<Node> children = [];

  Node(
    this.tagName, [
    Map<String, dynamic> attributes = const {},
    Iterable<Node> children = const [],
  ]) {
    this
      ..attributes.addAll(attributes)
      ..children.addAll(children);
  }

  Node._selfClosing(
    this.tagName, [
    Map<String, dynamic> attributes = const {},
  ]) {
    this.attributes.addAll(attributes);
  }

  /// Nodes are equal when they are of the same type, with equal tag names, attributes and children.
  @override
  bool operator ==(other) {
    return other is Node &&
        other.runtimeType == runtimeType &&
        other.tagName == tagName &&
        const ListEquality<Node>().equals(other.children, children) &&
        const MapEquality<String, dynamic>().equals(
          other.attributes,
          attributes,
        );
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    tagName,
    const ListEquality<Node>().hash(children),
    const MapEquality<String, dynamic>().hash(attributes),
  );
}

/// Represents a self-closing tag, i.e. `<br>`.
class SelfClosingNode extends Node {
  /*
  @override
  final String tagName;

  @override
  final Map<String, dynamic> attributes = {};
  */

  @override
  List<Node> get children => List<Node>.unmodifiable([]);

  // ignore: use_super_parameters
  SelfClosingNode(String tagName, [Map<String, dynamic> attributes = const {}])
    : super._selfClosing(tagName, attributes);
}

/// Represents a text node. Its text is HTML-escaped when rendered.
class TextNode extends Node {
  final String text;

  TextNode(this.text) : super(':text');

  @override
  bool operator ==(other) =>
      other is TextNode &&
      other.runtimeType == runtimeType &&
      other.text == text;

  @override
  int get hashCode => Object.hash(runtimeType, text);
}

/// Represents HTML that is rendered as-is, without escaping.
///
/// Never put untrusted input in a [RawNode]: it can inject any HTML, including scripts.
class RawNode extends TextNode {
  RawNode(super.html);
}
