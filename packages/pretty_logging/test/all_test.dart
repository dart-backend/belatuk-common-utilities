import 'package:belatuk_pretty_logging/belatuk_pretty_logging.dart';
import 'package:io/ansi.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

void main() {
  var error = StateError('Wrong!');
  var stack = StackTrace.fromString('#0 main');

  List<String> log(LogRecord record, {bool Function(LogRecord)? omitError}) {
    var printed = <String>[];
    overrideAnsiOutput(false, () {
      prettyLog(record, omitError: omitError, printFunction: printed.add);
    });
    return printed;
  }

  test('a record without an error is one line', () {
    var record = LogRecord(Level.INFO, 'Hey!', 'test');
    expect(log(record), equals(['$record']));
  });

  test(
    'a record with an error is printed in one call, without blank lines',
    () {
      var record = LogRecord(Level.SEVERE, 'Oops!', 'test', error, stack);
      expect(log(record), equals(['$record\n$error\n$stack']));
    },
  );

  test('omitError hides the error and stack trace, not the message', () {
    var record = LogRecord(Level.WARNING, 'Request failed', 'test', error);
    expect(log(record, omitError: (_) => true), equals(['$record']));
  });

  test('each line is wrapped in its color', () {
    var multiLineStack = StackTrace.fromString('#0 main\n#1 run');
    var record = LogRecord(
      Level.SEVERE,
      'Oops!',
      'test',
      error,
      multiLineStack,
    );
    var printed = <String>[];
    overrideAnsiOutput(true, () {
      prettyLog(record, printFunction: printed.add);
    });
    String colored(String line) => '${red.escape}$line${resetAll.escape}';
    expect(
      printed,
      equals([
        [
          colored('$record'),
          colored('$error'),
          colored('#0 main'),
          colored('#1 run'),
        ].join('\n'),
      ]),
    );
  });

  test('a stack trace without an error is printed', () {
    var record = LogRecord(Level.SEVERE, 'boom', 'test', null, stack);
    expect(log(record), equals(['$record\n$stack']));
  });

  test('omitError can hide a stack trace without an error', () {
    var record = LogRecord(Level.WARNING, 'x', 'test', null, stack);
    expect(log(record, omitError: (_) => true), equals(['$record']));
  });

  test('omitError returning false prints everything', () {
    var record = LogRecord(Level.SEVERE, 'Oops!', 'test', error, stack);
    expect(
      log(record, omitError: (_) => false),
      equals(['$record\n$error\n$stack']),
    );
  });

  test('omitError is not asked about a record with nothing to hide', () {
    var asked = false;
    var record = LogRecord(Level.INFO, 'Hey!', 'test');
    log(
      record,
      omitError: (_) {
        asked = true;
        return true;
      },
    );
    expect(asked, isFalse);
  });

  test('Windows line endings leave no stray carriage return', () {
    var record = LogRecord(
      Level.SEVERE,
      'Oops!',
      'test',
      error,
      StackTrace.fromString('#0 main\r\n#1 run'),
    );
    var printed = <String>[];
    overrideAnsiOutput(true, () {
      prettyLog(record, printFunction: printed.add);
    });
    expect(printed.single, isNot(contains('\r')));
    expect(printed.single, contains('${red.escape}#0 main${resetAll.escape}'));
  });

  test('levels are colored by value, including custom levels', () {
    expect(chooseLogColor(Level.SHOUT), equals(backgroundRed));
    expect(chooseLogColor(Level.OFF), equals(resetAll));
    expect(chooseLogColor(Level('FATAL', 1300)), equals(backgroundRed));
    expect(chooseLogColor(Level.SEVERE), equals(red));
    expect(chooseLogColor(Level('CRITICAL', 1100)), equals(red));
    expect(chooseLogColor(Level.WARNING), equals(yellow));
    expect(chooseLogColor(Level('NOTICE', 850)), equals(cyan));
    expect(chooseLogColor(Level.INFO), equals(cyan));
    expect(chooseLogColor(Level.CONFIG), equals(lightGray));
    expect(chooseLogColor(Level.ALL), equals(lightGray));
  });
}
