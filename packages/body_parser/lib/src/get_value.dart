import 'dart:convert';

/// A plain decimal number: an optional `-`, no leading zeros, an optional
/// fraction, and no `+`, exponent, hex or whitespace.
final _numberRgx = RegExp(r'^-?(0|[1-9]\d*)(\.\d+)?$');
final _nonSignificantRgx = RegExp(r'^[-0.]+|\.');

/// A double holds this many significant decimal digits exactly.
const _maxDoubleDigits = 15;

dynamic getValue(String value) {
  if (_numberRgx.hasMatch(value)) {
    // A number that cannot be held exactly keeps its digits as a string.
    if (!value.contains('.')) {
      return int.tryParse(value) ?? value;
    }
    var digits = value.replaceAll(_nonSignificantRgx, '').length;
    return digits <= _maxDoubleDigits ? double.parse(value) : value;
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
