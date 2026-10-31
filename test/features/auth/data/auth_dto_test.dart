import 'package:cardo/core/network/json_fields.dart';
import 'package:cardo/features/auth/data/auth_dto.dart';
import 'package:cardo/features/auth/domain/auth_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/api_json.dart';

final DateTime _now = DateTime.utc(2026, 3, 1, 12);

AuthTokens tokensAt(Object? raw) => tokensFromJson(raw, now: _now);

AuthGrant grantAt(Object? raw) => grantFromJson(raw, now: _now);

void main() {
  _negativeLifetime();
  group('userFromJson', () {
    test('maps a schema-conformant user', () {
      final user = userFromJson(<String, Object?>{
        'id': '0190a1f2-0000-7000-8000-000000000001',
        'email': 'anna@example.com',
        'display_name': 'Anna',
        'avatar_color': '#7C3AED',
        'created_at': '2026-03-01T12:00:00Z',
      });

      expect(user.id, '0190a1f2-0000-7000-8000-000000000001');
      expect(user.email, 'anna@example.com');
      expect(user.displayName, 'Anna');
      expect(user.avatarColor, '#7C3AED');
      expect(user.createdAt, DateTime.utc(2026, 3, 1, 12));
      expect(user.createdAt.isUtc, isTrue);
    });

    test('converts offset timestamps to UTC', () {
      final user = userFromJson(
        userJson()..['created_at'] = '2026-03-01T15:30:00+03:00',
      );

      expect(user.createdAt, DateTime.utc(2026, 3, 1, 12, 30));
      expect(user.createdAt.isUtc, isTrue);
    });

    test('keeps fractional seconds', () {
      final user = userFromJson(
        userJson()..['created_at'] = '2026-03-01T12:00:00.123456Z',
      );

      expect(user.createdAt, DateTime.utc(2026, 3, 1, 12, 0, 0, 123, 456));
    });

    test('normalizes avatar_color to upper case #RRGGBB', () {
      expect(
        userFromJson(userJson(avatarColor: '#7c3aed')).avatarColor,
        '#7C3AED',
      );
      expect(
        userFromJson(userJson(avatarColor: '7c3aed')).avatarColor,
        '#7C3AED',
      );
      expect(
        userFromJson(userJson(avatarColor: ' #0ea5e9 ')).avatarColor,
        '#0EA5E9',
      );
    });

    test('rejects malformed avatar colors', () {
      for (final bad in <String>[
        '',
        '#fff',
        '#12345',
        '#1234567',
        'red',
        '#GGGGGG',
      ]) {
        expect(
          () => userFromJson(userJson(avatarColor: bad)),
          throwsFormatException,
          reason: bad,
        );
      }
    });

    for (final field in <String>[
      'id',
      'email',
      'display_name',
      'avatar_color',
      'created_at',
    ]) {
      test('requires $field', () {
        expect(
          () => userFromJson(userJson()..remove(field)),
          throwsFormatException,
        );
      });

      test('rejects a non-string $field', () {
        expect(
          () => userFromJson(userJson()..[field] = 5),
          throwsFormatException,
        );
        expect(
          () => userFromJson(userJson()..[field] = null),
          throwsFormatException,
        );
      });
    }

    test('rejects an empty id and an unparsable date', () {
      expect(() => userFromJson(userJson(id: '')), throwsFormatException);
      expect(
        () => userFromJson(userJson()..['created_at'] = 'yesterday'),
        throwsFormatException,
      );
    });

    test('rejects non-objects', () {
      for (final raw in <Object?>[null, 'x', 1, <Object?>[]]) {
        expect(() => userFromJson(raw), throwsFormatException);
      }
    });

    test('ignores unknown fields', () {
      expect(userFromJson(userJson()..['extra'] = 1).id, annaId);
    });
  });

  group('tokensFromJson', () {
    test('maps a schema-conformant token response without user', () {
      final tokens = tokensAt(<String, Object?>{
        'token_type': 'Bearer',
        'access_token': 'a.b.c',
        'access_expires_at': '2026-03-01T12:15:00Z',
        'expires_in': 900,
        'refresh_token': 'r-token',
        'refresh_expires_at': '2026-03-31T12:00:00Z',
      });

      expect(tokens.access, 'a.b.c');
      expect(tokens.accessExpiresAt, DateTime.utc(2026, 3, 1, 12, 15));
      expect(tokens.refresh, 'r-token');
      expect(tokens.refreshExpiresAt, DateTime.utc(2026, 3, 31, 12));
      expect(tokens.accessExpiresAt.isUtc, isTrue);
      expect(tokens.refreshExpiresAt.isUtc, isTrue);
    });

    test('access expiry comes from expires_in and the local clock', () {
      final tokens = tokensAt(
        tokenJson()
          ..['access_expires_at'] = '2000-01-01T00:00:00Z'
          ..['expires_in'] = 60
          ..['refresh_expires_at'] = '2026-03-31T07:00:00-05:00',
      );

      expect(tokens.accessExpiresAt, DateTime.utc(2026, 3, 1, 12, 1));
      expect(tokens.refreshExpiresAt, DateTime.utc(2026, 3, 31, 12));
    });

    for (final field in <String>[
      'access_token',
      'expires_in',
      'refresh_token',
      'refresh_expires_at',
    ]) {
      test('requires $field', () {
        expect(
          () => tokensAt(tokenJson()..remove(field)),
          throwsFormatException,
        );
      });
    }

    test('rejects empty tokens', () {
      expect(() => tokensAt(tokenJson(access: '')), throwsFormatException);
      expect(() => tokensAt(tokenJson(refresh: '')), throwsFormatException);
    });

    test('does not require access_expires_at or token_type', () {
      final tokens = tokensAt(
        tokenJson()
          ..remove('access_expires_at')
          ..remove('token_type'),
      );

      expect(tokens.access, 'access-1');
    });

    test('rejects non-objects', () {
      expect(() => tokensAt(null), throwsFormatException);
      expect(() => tokensAt('x'), throwsFormatException);
    });
  });

  group('grantFromJson', () {
    test('combines tokens and user', () {
      final grant = grantAt(tokenJson(user: userJson()));

      expect(grant.tokens.access, 'access-1');
      expect(grant.user.id, annaId);
    });

    test('a refresh-style response without user is rejected', () {
      expect(() => grantAt(tokenJson()), throwsFormatException);
    });

    test('a malformed nested user is rejected', () {
      expect(
        () => grantAt(tokenJson(user: userJson()..remove('email'))),
        throwsFormatException,
      );
    });

    test('malformed tokens are rejected even with a valid user', () {
      expect(
        () => grantAt(tokenJson(user: userJson())..remove('refresh_token')),
        throwsFormatException,
      );
    });

    test('equality is by value', () {
      final a = grantAt(tokenJson(user: userJson()));
      final b = grantAt(tokenJson(user: userJson()));

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('json_fields', () {
    test('readInt accepts only integers', () {
      expect(readInt(<String, dynamic>{'n': 3}, 'n'), 3);
      expect(
        () => readInt(<String, dynamic>{'n': 3.5}, 'n'),
        throwsFormatException,
      );
      expect(
        () => readInt(<String, dynamic>{'n': '3'}, 'n'),
        throwsFormatException,
      );
      expect(() => readInt(<String, dynamic>{}, 'n'), throwsFormatException);
    });

    test('readObjectList validates every item', () {
      expect(
        readObjectList(<String, dynamic>{
          'xs': <Object?>[
            <String, Object?>{'a': 1},
          ],
        }, 'xs'),
        hasLength(1),
      );
      expect(
        () => readObjectList(<String, dynamic>{
          'xs': <Object?>[1],
        }, 'xs'),
        throwsFormatException,
      );
      expect(
        () => readObjectList(<String, dynamic>{'xs': 'no'}, 'xs'),
        throwsFormatException,
      );
      expect(
        () => readObjectList(<String, dynamic>{}, 'xs'),
        throwsFormatException,
      );
    });

    test('readDate converts to UTC and rejects garbage', () {
      expect(
        readDate(<String, dynamic>{'d': '2026-01-01T03:00:00+03:00'}, 'd'),
        DateTime.utc(2026),
      );
      expect(
        () => readDate(<String, dynamic>{'d': 'nope'}, 'd'),
        throwsFormatException,
      );
    });

    test('error messages never echo the offending value', () {
      try {
        readNonEmptyString(<String, dynamic>{
          'access_token': '',
        }, 'access_token');
        fail('expected FormatException');
      } on FormatException catch (error) {
        expect(error.message, isNot(contains('"":')));
      }
    });
  });
}

void _negativeLifetime() {
  test('rejects a negative expires_in', () {
    expect(
      () => tokensAt(tokenJson()..['expires_in'] = -1),
      throwsFormatException,
    );
  });
}
