import 'package:source_span/source_span.dart';

/// An advanced StringBuffer geared toward generating code, and source maps.
class CodeBuffer implements StringBuffer {
  /// The character sequence used to represent a line break.
  final String newline;

  /// The character sequence used to represent a space/tab.
  final String space;

  /// The source URL to be applied to all generated [SourceSpan] instances.
  final dynamic sourceUrl;

  /// If `true` (default: `false`), then an additional [newline] will be inserted at the end of the generated string.
  final bool trailingNewline;

  final List<CodeBufferLine> _lines = [];
  CodeBufferLine? _currentLine, _lastLine;
  int _indentationLevel = 0;
  int _length = 0;

  CodeBuffer({
    this.space = '  ',
    this.newline = '\n',
    this.trailingNewline = false,
    this.sourceUrl,
  });

  /// Creates a [CodeBuffer] that does not emit additional whitespace.
  factory CodeBuffer.noWhitespace({dynamic sourceUrl}) => CodeBuffer(
    space: '',
    newline: '',
    trailingNewline: false,
    sourceUrl: sourceUrl,
  );

  /// The last line created within this buffer.
  CodeBufferLine? get lastLine => _lastLine;

  /// Returns an immutable collection of the [CodeBufferLine]s within this instance.
  List<CodeBufferLine> get lines => List<CodeBufferLine>.unmodifiable(_lines);

  @override
  bool get isEmpty => _lines.isEmpty;

  @override
  bool get isNotEmpty => _lines.isNotEmpty;

  /// The length of [toString], including indentation, line breaks and any trailing newline.
  @override
  int get length => _length + (trailingNewline ? newline.length : 0);

  CodeBufferLine _createLine([int? indentationLevel]) {
    var level = indentationLevel ?? _indentationLevel;
    var column = level * space.length;
    if (_lines.isNotEmpty) _length += newline.length;
    _length += column;
    var start = SourceLocation(
      _length,
      sourceUrl: sourceUrl,
      line: _lines.length,
      column: column,
    );
    var line = CodeBufferLine._(level, start).._end = start;
    _lines.add(_lastLine = line);
    return line;
  }

  /// Increments the indentation level.
  void indent() {
    _indentationLevel++;
  }

  /// Decrements the indentation level, if it is greater than `0`.
  void outdent() {
    if (_indentationLevel > 0) _indentationLevel--;
  }

  /// Copies the contents of this [CodeBuffer] into another, preserving indentation and source mapping information.
  ///
  /// The copied lines always start on a new line in [other], and the last one is terminated.
  ///
  /// Each line's [CodeBufferLine.sourceMappings] are copied unchanged. Their spans are not moved to
  /// the line's new position, since a [CodeBuffer] cannot tell which of them are generated spans.
  void copyInto(CodeBuffer other) {
    if (_lines.isEmpty) return;
    other._currentLine = null;

    // Iterate over a copy when copying a buffer into itself.
    var lines = identical(this, other) ? List.of(_lines) : _lines;
    for (var line in lines) {
      var text = line.text;
      var clone = other._createLine(
        text.isEmpty ? 0 : other._indentationLevel + line.indentationLevel,
      );
      var start = clone._start;
      clone._buf.write(text);
      clone._end = SourceLocation(
        start.offset + text.length,
        sourceUrl: other.sourceUrl,
        line: start.line,
        column: start.column + text.length,
      );
      clone.sourceMappings.addAll(line.sourceMappings);
      other._length += text.length;

      // Rebase lastSpan, keeping its position relative to the start of the line.
      var lastSpan = line._lastSpan;
      if (lastSpan != null) {
        var delta = lastSpan.start.column - line._start.column;
        clone._lastSpan = SourceSpan(
          SourceLocation(
            start.offset + delta,
            sourceUrl: other.sourceUrl,
            line: start.line,
            column: start.column + delta,
          ),
          SourceLocation(
            start.offset + delta + lastSpan.length,
            sourceUrl: other.sourceUrl,
            line: start.line,
            column: start.column + delta + lastSpan.length,
          ),
          lastSpan.text,
        );
      }
    }
  }

  @override
  void clear() {
    _lines.clear();
    _length = _indentationLevel = 0;
    _currentLine = _lastLine = null;
  }

  @override
  void writeCharCode(int charCode) {
    _write(String.fromCharCode(charCode));
  }

  /// Writes [obj] to the current line, unchanged.
  ///
  /// Line breaks within [obj] are written as-is, without indentation, and do not start a new
  /// [CodeBufferLine]. Use [writeln] to end lines if line and column numbers must stay accurate.
  @override
  void write(Object? obj) {
    _write(obj.toString());
  }

  void _write(String msg) {
    var line = _currentLine ??= _createLine();
    line._buf.write(msg);
    var end = line._end;
    line._end = SourceLocation(
      end.offset + msg.length,
      sourceUrl: end.sourceUrl,
      line: end.line,
      column: end.column + msg.length,
    );
    _length += msg.length;
    line._lastSpan = SourceSpan(end, line._end, msg);
  }

  /// Terminates the current line, first creating a blank one, without indentation, if necessary.
  void _endLine() {
    _currentLine ??= _createLine(0);
    _currentLine = null;
  }

  @override
  void writeln([Object? obj = '']) {
    if (obj != null && obj != '') write(obj);
    _endLine();
  }

  @override
  void writeAll(Iterable objects, [String separator = '']) {
    write(objects.join(separator));
  }

  @override
  String toString() {
    var buf = StringBuffer();
    var i = 0;

    for (var line in _lines) {
      if (i++ > 0) buf.write(newline);
      for (var j = 0; j < line.indentationLevel; j++) {
        buf.write(space);
      }
      buf.write(line._buf.toString());
    }

    if (trailingNewline == true) buf.write(newline);

    return buf.toString();
  }
}

/// Represents a line of text within a [CodeBuffer].
class CodeBufferLine {
  /// Mappings from one [SourceSpan] to another, to aid with generating dynamic source maps.
  final Map<SourceSpan, SourceSpan> sourceMappings = {};

  /// The level of indentation preceding this line.
  final int indentationLevel;

  final SourceLocation _start;
  final StringBuffer _buf = StringBuffer();
  late SourceLocation _end;
  SourceSpan? _lastSpan;

  CodeBufferLine._(this.indentationLevel, this._start);

  /// The [SourceSpan] corresponding to the last text written to this line.
  SourceSpan? get lastSpan => _lastSpan;

  /// The [SourceSpan] corresponding to this entire line.
  SourceSpan get span => SourceSpan(_start, _end, _buf.toString());

  /// The text within this line.
  String get text => _buf.toString();
}
