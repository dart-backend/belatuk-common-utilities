import 'dart:convert';

/// A plain decimal number: an optional `-`, no leading zeros, an optional
/// fraction, and no `+`, exponent, hex or whitespace.
final _numberRgx = RegExp(r'^-?(0|[1-9]\d*)(\.\d+)?$');

final _nonZeroDigitRgx = RegExp('[1-9]');

/// A double holds this many significant decimal digits exactly.
const _maxDoubleDigits = 15;

/// The smallest positive double that keeps full precision. Smaller values
/// are subnormal and lose digits.
const _minNormalDouble = 2.2250738585072014e-308;

dynamic getValue(String value) {
  if (_numberRgx.hasMatch(value)) {
    // A number that cannot be held exactly keeps its digits as a string.
    var point = value.indexOf('.');
    if (point == -1) {
      return int.tryParse(value) ?? value;
    }

    // The significant digits run from the first to the last non-zero digit.
    var first = value.indexOf(_nonZeroDigitRgx);
    if (first == -1) {
      // -0.0 loses its sign, the same as -0 does as an int.
      return 0.0;
    }
    var last = value.lastIndexOf(_nonZeroDigitRgx);
    var significant =
        last - first + 1 - (first < point && point < last ? 1 : 0);
    if (significant > _maxDoubleDigits) {
      return value;
    }
    var parsed = double.parse(value);
    if (parsed.isInfinite || parsed.abs() < _minNormalDouble) {
      return value;
    }
    return parsed;
  } else if ((value.startsWith('[') && value.endsWith(']')) ||
      (value.startsWith('{') && value.endsWith('}'))) {
    // Text such as "[draft]" only looks like JSON, so keep it as a string.
    try {
      return json.decode(value);
    } on FormatException {
      return value;
    }
  } else if (value.trim().toLowerCase() == 'null') {
    return null;
  } else {
    return value;
  }
}
