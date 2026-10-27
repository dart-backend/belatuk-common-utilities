import 'node.dart';
import 'node_builder.dart';

/// Returns a function that rebuilds an arbitrary [Node] by applying the [transform] to it.
///
/// [TextNode]s are returned unchanged. Other nodes stay self-closing or not, unless
/// [selfClosing] is given.
Node Function(Node) rebuild(
  NodeBuilder Function(NodeBuilder) transform, {
  bool? selfClosing,
}) {
  return (node) => node is TextNode
      ? node
      : transform(NodeBuilder.from(node)).build(selfClosing: selfClosing);
}

/// Applies [f] to all children of this node, recursively.
///
/// Use this alongside [rebuild].
Node Function(Node) rebuildRecursive(Node Function(Node) f) {
  Node build(Node node) {
    var result = f(node);
    if (result is TextNode) return result;
    return NodeBuilder.from(result).mapChildren(build).build();
  }

  return build;
}
