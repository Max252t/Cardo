import 'package:cardo/features/auth/domain/auth_validation.dart';
import 'package:flutter_test/flutter_test.dart';

const String emoji = '\u{1F600}';

String emailOfLength(int length) {
  const domain = '@example.com';
  return '${'a' * (length - domain.length)}$domain';
}

void main() {
  test('limits match the server contract', () {
    expect(AuthLimits.passwordMin, 8);
    expect(AuthLimits.passwordMax, 128);
    expect(AuthLimits.nameMax, 100);
    expect(AuthLimits.emailMax, 254);
  });

  group('newPassword', () {
    test('empty', () {
      expect(AuthValidators.newPassword(''), FieldIssue.empty);
    });

    test('7 is too short, 8 is fine', () {
      expect(AuthValidators.newPassword('a' * 7), FieldIssue.tooShort);
      expect(AuthValidators.newPassword('a' * 8), isNull);
    });

    test('128 is fine, 129 is too long', () {
      expect(AuthValidators.newPassword('a' * 128), isNull);
      expect(AuthValidators.newPassword('a' * 129), FieldIssue.tooLong);
    });

    test('spaces count as characters and are not trimmed', () {
      expect(AuthValidators.newPassword(' ' * 8), isNull);
    });

    test('surrogate pairs count once', () {
      expect(AuthValidators.newPassword(emoji * 8), isNull);
      expect(AuthValidators.newPassword(emoji * 7), FieldIssue.tooShort);
      expect(AuthValidators.newPassword(emoji * 128), isNull);
      expect(AuthValidators.newPassword(emoji * 129), FieldIssue.tooLong);
    });
  });

  group('loginPassword', () {
    test('only emptiness is checked', () {
      expect(AuthValidators.loginPassword(''), FieldIssue.empty);
      expect(AuthValidators.loginPassword('x'), isNull);
      expect(AuthValidators.loginPassword(' '), isNull);
    });
  });

  group('name', () {
    test('empty and blank', () {
      expect(AuthValidators.name(''), FieldIssue.empty);
      expect(AuthValidators.name('    '), FieldIssue.empty);
    });

    test('1 and 100 are fine, 101 is too long', () {
      expect(AuthValidators.name('a'), isNull);
      expect(AuthValidators.name('a' * 100), isNull);
      expect(AuthValidators.name('a' * 101), FieldIssue.tooLong);
    });

    test('padding is trimmed before counting', () {
      expect(AuthValidators.name('  ${'a' * 100}  '), isNull);
    });

    test('surrogate pairs count once', () {
      expect(AuthValidators.name(emoji * 100), isNull);
      expect(AuthValidators.name(emoji * 101), FieldIssue.tooLong);
    });

    test('non-latin names', () {
      expect(AuthValidators.name('Анна'), isNull);
    });
  });

  group('email', () {
    test('empty and blank', () {
      expect(AuthValidators.email(''), FieldIssue.empty);
      expect(AuthValidators.email('   '), FieldIssue.empty);
    });

    test('accepts ordinary addresses and trims', () {
      expect(AuthValidators.email('a@b.co'), isNull);
      expect(AuthValidators.email('  anna.k+tag@mail.example.com '), isNull);
    });

    test('rejects malformed addresses', () {
      for (final bad in <String>[
        'plain',
        'a@b',
        '@b.co',
        'a@.co',
        'a b@c.de',
        'a@@b.co',
        'a@b c.co',
      ]) {
        expect(
          AuthValidators.email(bad),
          FieldIssue.invalidFormat,
          reason: bad,
        );
      }
    });

    test('the limit is 254 UTF-8 bytes of the lowercased address', () {
      final local = 'ж' * 125;
      expect(AuthValidators.email('$local@a.ru'), FieldIssue.tooLong);
      expect(AuthValidators.email('${'ж' * 124}@a.ru'), isNull);
    });

    test('254 is fine, 255 is too long', () {
      expect(emailOfLength(254).length, 254);
      expect(AuthValidators.email(emailOfLength(254)), isNull);
      expect(AuthValidators.email(emailOfLength(255)), FieldIssue.tooLong);
    });

    test('padding does not count towards the limit', () {
      expect(AuthValidators.email('  ${emailOfLength(254)}  '), isNull);
    });
  });

  group('loginEmail', () {
    test('only emptiness is checked', () {
      expect(AuthValidators.loginEmail(''), FieldIssue.empty);
      expect(AuthValidators.loginEmail('   '), FieldIssue.empty);
      expect(AuthValidators.loginEmail('not-an-email'), isNull);
    });
  });
}
