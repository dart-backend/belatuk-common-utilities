import 'package:belatuk_html_builder/elements.dart';
import 'package:test/test.dart';

String render(Node node) =>
    StringRenderer(pretty: false, doctype: '').render(node);

void main() {
  group('escaping', () {
    test('escapes text', () {
      expect(
        render(p(c: [text('<script>alert(1)</script> & co')])),
        '<p>&lt;script&gt;alert(1)&lt;/script&gt; &amp; co</p>',
      );
    });

    test('escapes attribute values', () {
      expect(
        render(a(href: '/x?a=1&b="2"', c: [text('x')])),
        '<a href="/x?a=1&amp;b=&quot;2&quot;">x</a>',
      );
      expect(
        render(div(className: ['a"', 'b'], style: {'color': '<red>'})),
        '<div class="a&quot; b" style="color: &lt;red&gt;;"></div>',
      );
    });

    test('raw nodes are not escaped', () {
      expect(render(p(c: [raw('<b>bold</b>')])), '<p><b>bold</b></p>');
    });

    test('text in script and style is not escaped', () {
      expect(
        render(script(c: [text('if (a < b && c) {}')])),
        '<script>if (a < b && c) {}</script>',
      );
      expect(render(style(c: [text('a > b {}')])), '<style>a > b {}</style>');
    });

    test('the pretty renderer escapes too', () {
      expect(
        StringRenderer(doctype: '').render(p(c: [text('a < b')])),
        '<p>\n  a &lt; b\n</p>',
      );
    });
  });

  group('elements', () {
    test('abbr renders <abbr>', () {
      expect(render(abbr(title: 'HTML')), '<abbr title="HTML"></abbr>');
    });

    test('void elements have no closing tag', () {
      expect(render(col(span: 2)), '<col span="2">');
      expect(render(wbr()), '<wbr>');
      expect(render(keygen(name: 'k')), '<keygen name="k">');
    });

    test('iframe has a closing tag', () {
      expect(render(iframe(src: '/x')), '<iframe src="/x"></iframe>');
    });

    test('article takes id, and any class and style value', () {
      expect(
        render(
          article(id: 'x', className: ['a', 'b'], style: {'color': 'red'}),
        ),
        '<article id="x" class="a b" style="color: red;"></article>',
      );
    });

    test('new helpers', () {
      expect(render(data(value: '1')), '<data value="1"></data>');
      expect(
        render(meter(value: 0.5, max: 1)),
        '<meter value="0.5" max="1"></meter>',
      );
      expect(render(template()), '<template></template>');
      expect(render(slot(name: 's')), '<slot name="s"></slot>');
      expect(render(search()), '<search></search>');
      expect(render(hgroup()), '<hgroup></hgroup>');
    });
  });

  group('NodeBuilder', () {
    test('addClass does not duplicate an existing class', () {
      var node = NodeBuilder.from(h('b', {'class': 'btn primary'}))
          .addClass('primary')
          .addClass('large')
          .build();
      expect(node.attributes['class'], 'btn primary large');
    });

    test('rebuild keeps self-closing nodes and text', () {
      var f = rebuild((b) => b.setId('x'));
      expect(render(f(br())), '<br id="x">');
      expect(f(text('hi')), text('hi'));
    });

    test('rebuildRecursive keeps text and self-closing nodes', () {
      var f = rebuildRecursive(rebuild((b) => b.addClass('c')));
      expect(
        render(f(p(c: [text('Hi'), br()]))),
        '<p class="c">Hi<br class="c"></p>',
      );
    });
  });

  group('equality', () {
    test('nodes of different types are not equal', () {
      expect(Node('br') == SelfClosingNode('br'), isFalse);
      expect(Node(':text') == TextNode('hi'), isFalse);
      expect(TextNode('hi') == Node(':text'), isFalse);
      expect(TextNode('x') == RawNode('x'), isFalse);
    });

    test('equal nodes have equal hash codes regardless of attribute order', () {
      var a = h('a', {'x': 1, 'y': 2});
      var b = h('a', {'y': 2, 'x': 1});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
