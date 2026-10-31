import 'package:cardo/core/network/api_failure.dart';
import 'package:cardo/l10n/app_localizations.dart';
import 'package:cardo/shared/errors/api_failure_text.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    group('describeApiFailure ${locale.languageCode}', () {
      final l10n = lookupAppLocalizations(locale);

      test('maps every failure to its string', () {
        final expected = <ApiFailure, String>{
          const InvalidCredentialsFailure(): l10n.loginInvalidCredentials,
          const EmailTakenFailure(): l10n.registerEmailTaken,
          const ValidationFailure(): l10n.errorValidation,
          const ValidationFailure(message: 'server says no'):
              l10n.errorValidation,
          const UnauthorizedFailure(UnauthorizedKind.missing):
              l10n.errorSessionExpired,
          const UnauthorizedFailure(UnauthorizedKind.invalidToken):
              l10n.errorSessionExpired,
          const UnauthorizedFailure(UnauthorizedKind.tokenExpired):
              l10n.errorSessionExpired,
          const UnauthorizedFailure(UnauthorizedKind.tokenReused):
              l10n.errorSessionReused,
          const ForbiddenFailure(): l10n.errorForbidden,
          const NotFoundFailure(): l10n.errorNotFound,
          const GoneFailure(): l10n.errorUnknown,
          const BusyFailure(): l10n.errorBusy,
          const BusyFailure(retryAfter: Duration(seconds: 3)): l10n.errorBusy,
          const NetworkFailure(NetworkFailureKind.offline):
              l10n.errorNetworkOffline,
          const NetworkFailure(NetworkFailureKind.timeout):
              l10n.errorNetworkTimeout,
          const UnknownFailure(): l10n.errorUnknown,
          const UnknownFailure(statusCode: 500, code: 'internal'):
              l10n.errorUnknown,
        };

        for (final entry in expected.entries) {
          expect(
            describeApiFailure(l10n, entry.key),
            entry.value,
            reason: '${entry.key}',
          );
        }
      });

      test('rate limiting reports seconds, then minutes rounded up', () {
        String text(Duration? after) =>
            describeApiFailure(l10n, RateLimitedFailure(retryAfter: after));

        expect(text(null), l10n.errorRateLimited);
        expect(text(Duration.zero), l10n.errorRateLimited);
        expect(
          text(const Duration(seconds: 1)),
          l10n.errorRateLimitedSeconds(1),
        );
        expect(
          text(const Duration(seconds: 59)),
          l10n.errorRateLimitedSeconds(59),
        );
        expect(
          text(const Duration(seconds: 60)),
          l10n.errorRateLimitedMinutes(1),
        );
        expect(
          text(const Duration(seconds: 61)),
          l10n.errorRateLimitedMinutes(2),
        );
        expect(
          text(const Duration(seconds: 120)),
          l10n.errorRateLimitedMinutes(2),
        );
        expect(
          text(const Duration(seconds: 121)),
          l10n.errorRateLimitedMinutes(3),
        );
      });

      test('the seconds and minutes variants mention the number', () {
        final seconds = describeApiFailure(
          l10n,
          const RateLimitedFailure(retryAfter: Duration(seconds: 42)),
        );
        final minutes = describeApiFailure(
          l10n,
          const RateLimitedFailure(retryAfter: Duration(seconds: 180)),
        );

        expect(seconds, contains('42'));
        expect(minutes, contains('3'));
      });

      test('no message is empty', () {
        final messages = <String>[
          l10n.errorNetworkOffline,
          l10n.errorNetworkTimeout,
          l10n.errorBusy,
          l10n.errorRateLimited,
          l10n.errorForbidden,
          l10n.errorNotFound,
          l10n.errorValidation,
          l10n.errorUnknown,
          l10n.errorSessionExpired,
          l10n.errorSessionReused,
        ];

        expect(messages, everyElement(isNotEmpty));
        expect(messages.toSet(), hasLength(messages.length));
      });
    });
  }

  test('english wording of the contractual texts', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    expect(l10n.errorSessionExpired, 'Your session expired. Sign in again.');
    expect(l10n.errorSessionReused, contains('ended all sessions'));
  });

  test('russian wording of the contractual texts', () {
    final l10n = lookupAppLocalizations(const Locale('ru'));

    expect(l10n.errorSessionExpired, 'Сессия истекла, войдите снова.');
    expect(l10n.errorSessionReused, startsWith('Мы завершили все сессии'));
  });

  group('apiFailureCode', () {
    test('names every failure', () {
      final expected = <ApiFailure, String>{
        const InvalidCredentialsFailure(): 'invalid_credentials',
        const EmailTakenFailure(): 'email_taken',
        const ValidationFailure(): 'validation_error',
        const RateLimitedFailure(): 'rate_limited',
        const UnauthorizedFailure(UnauthorizedKind.tokenReused): 'unauthorized',
        const ForbiddenFailure(): 'forbidden',
        const NotFoundFailure(): 'not_found',
        const GoneFailure(): 'gone',
        const BusyFailure(): 'busy',
        const NetworkFailure(NetworkFailureKind.offline): 'network_offline',
        const NetworkFailure(NetworkFailureKind.timeout): 'network_timeout',
        const UnknownFailure(): 'unknown',
        const UnknownFailure(statusCode: 502): 'http_502',
        const UnknownFailure(statusCode: 418, code: 'teapot'): 'teapot',
      };

      for (final entry in expected.entries) {
        expect(apiFailureCode(entry.key), entry.value);
      }
    });
  });
}
