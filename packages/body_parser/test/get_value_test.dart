import 'package:belatuk_body_parser/src/get_value.dart';
import 'package:test/test.dart';

void main() {
  test('Plain decimal numbers are converted', () {
    expect(getValue('0'), equals(0));
    expect(getValue('42'), equals(42));
    expect(getValue('-7'), equals(-7));
    expect(getValue('2.0'), equals(2.0));
    expect(getValue('14.50000'), equals(14.5));
    expect(getValue('-0.000123'), equals(-0.000123));
    expect(getValue('9223372036854775807'), equals(9223372036854775807));
    expect(getValue('1.00000000000000000'), equals(1.0));
    expect(getValue('123456789012345.000'), equals(123456789012345.0));
    expect(getValue('0.${'0' * 300}1'), equals(1e-301));
    expect(getValue('0.${'0' * 400}'), equals(0.0));
    expect(getValue('0.${'0' * 307}25'), equals(2.5e-308));
    expect(getValue('17${'0' * 307}.0'), equals(1.7e308));
  });

  test('Negative zero loses its sign', () {
    expect(getValue('-0'), equals(0));
    expect((getValue('-0.0') as double).isNegative, isFalse);
    expect((getValue('-0.${'0' * 400}') as double).isNegative, isFalse);
  });

  test('Decimals that cannot be held exactly stay strings', () {
    for (var value in [
      '1234567890.1234567',
      '0.${'0' * 400}1',
      '0.${'0' * 310}1',
      '0.${'0' * 307}15',
      '0.${'0' * 308}1',
      '2${'0' * 308}.0',
      '1${'0' * 400}.0',
    ]) {
      expect(getValue(value), equals(value), reason: value);
    }
  });

  test('Other number-like text stays a string', () {
    for (var value in [
      '01234',
      '00.5',
      '+15551234567',
      ' 5',
      '5 ',
      '0x1F',
      '1e3',
      '.5',
      '5.',
      'Infinity',
      'NaN',
      '9223372036854775808',
      '12345678901234567890',
    ]) {
      expect(getValue(value), equals(value), reason: value);
    }
  });

  test('JSON and null', () {
    expect(getValue('[1,"a"]'), equals([1, 'a']));
    expect(getValue('{"a":1}'), equals({'a': 1}));
    expect(getValue('[draft]'), equals('[draft]'));
    expect(getValue('null'), isNull);
  });
}
