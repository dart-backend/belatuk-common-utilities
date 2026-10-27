import 'dart:convert';

import 'node.dart';

/// An object that can render a DOM tree into another representation, i.e. a `String`.
abstract class Renderer<T> {
  /// Renders a DOM tree into another representation.
  T render(Node rootNode);
}

/// Renders a DOM tree into a HTML string.
abstract class StringRenderer implements Renderer<String> {
  /// Initializes a new [StringRenderer].
  ///
  /// If [html5] is `true` (default), then self-closing elements are rendered without a slash, ex. `<br>`.
  /// If it is `false`, they are rendered with a slash before the last angle bracket, ex. `<br/>`.
  /// If [pretty] is `true` (default), then [whitespace] (default: `'  '`) will be inserted between nodes.
  /// You can also provide a [doctype] (default: `html`).
  ///
  /// Text and attribute values are HTML-escaped, except text inside `<script>` and `<style>`
  /// elements, and [RawNode]s, which are written as-is.
  factory StringRenderer({
    bool html5 = true,
    bool pretty = true,
    String doctype = 'html',
    String whitespace = '  ',
  }) => pretty == true
      ? _PrettyStringRendererImpl(
          html5: html5 != false,
          doctype: doctype,
          whitespace: whitespace,
        )
      : _StringRendererImpl(html5: html5 != false, doctype: doctype);
}

class _StringRendererImpl implements StringRenderer {
  final String? doctype;
  final bool? html5;

  _StringRendererImpl({this.html5, this.doctype});

  void _renderInto(Node node, StringBuffer buf, [Node? parent]) {
    if (node is TextNode) {
      _renderText(node, parent, buf);
    } else {
      buf.write('<${node.tagName}');

      _renderAttributes(node, buf);

      if (node is SelfClosingNode) {
        buf.write((html5 != false) ? '>' : '/>');
      } else {
        buf.write('>');
        for (var child in node.children) {
          _renderInto(child, buf, node);
        }
        buf.write('</${node.tagName}>');
      }
    }
  }

  @override
  String render(Node rootNode) {
    var buf = StringBuffer();
    if (doctype?.isNotEmpty == true) buf.write('<!DOCTYPE $doctype>');
    _renderInto(rootNode, buf);
    return buf.toString();
  }
}

class _PrettyStringRendererImpl implements StringRenderer {
  final bool? html5;
  final String? doctype, whitespace;

  _PrettyStringRendererImpl({this.html5, this.whitespace, this.doctype});

  void _applyTabs(int tabs, StringBuffer buf) {
    for (var i = 0; i < tabs; i++) {
      buf.write(whitespace ?? '  ');
    }
  }

  void _renderInto(int tabs, Node node, StringBuffer buf, [Node? parent]) {
    if (tabs > 0) buf.writeln();
    _applyTabs(tabs, buf);

    if (node is TextNode) {
      _renderText(node, parent, buf);
    } else {
      buf.write('<${node.tagName}');

      _renderAttributes(node, buf);

      if (node is SelfClosingNode) {
        buf.write((html5 != false) ? '>' : '/>');
      } else {
        buf.write('>');
        for (var child in node.children) {
          _renderInto(tabs + 1, child, buf, node);
        }
        buf.writeln();
        _applyTabs(tabs, buf);
        buf.write('</${node.tagName}>');
      }
    }
  }

  @override
  String render(Node rootNode) {
    var buf = StringBuffer();
    if (doctype?.isNotEmpty == true) buf.writeln('<!DOCTYPE $doctype>');
    _renderInto(0, rootNode, buf);
    return buf.toString();
  }
}

const _escapeText = HtmlEscape(HtmlEscapeMode.element);
const _escapeAttribute = HtmlEscape(HtmlEscapeMode.attribute);

/// Elements whose text browsers do not decode, so it must not be escaped.
const _rawTextElements = {'script', 'style'};

void _renderText(TextNode node, Node? parent, StringBuffer buf) {
  if (node is RawNode || _rawTextElements.contains(parent?.tagName)) {
    buf.write(node.text);
  } else {
    buf.write(_escapeText.convert(node.text));
  }
}

void _renderAttributes(Node node, StringBuffer buf) {
  node.attributes.forEach((k, v) {
    if (v == true) {
      buf.write(' $k');
    } else if (v == false || v == null) {
      // Ignore
    } else {
      String val;
      if (v is Iterable) {
        val = v.join(' ');
      } else if (v is Map) {
        val = v.keys.fold<String>('', (out, k) => out += '$k: ${v[k]};');
      } else {
        val = v.toString();
      }
      buf.write(' $k="${_escapeAttribute.convert(val)}"');
    }
  });
}
