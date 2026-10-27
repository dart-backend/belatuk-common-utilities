import 'package:test/test.dart';

import 'list_test.dart' as list;
import 'match_test.dart' as match;
import 'misc_test.dart' as misc;
import 'parse_test.dart' as parse;
import 'recursion_test.dart' as recursion;
import 'stringify_test.dart' as stringify;
import 'value_test.dart' as value;

void main() {
  group('list', list.main);
  group('match', match.main);
  group('value', value.main);
  misc.main();
  group('parse', parse.main);
  group('recursion', recursion.main);
  group('stringify', stringify.main);
}
