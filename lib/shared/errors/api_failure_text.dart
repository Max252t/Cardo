import '../../core/network/api_failure.dart';
import '../../l10n/app_localizations.dart';

const int _secondsPerMinute = 60;

String describeApiFailure(AppLocalizations l10n, ApiFailure failure) {
  return switch (failure) {
    InvalidCredentialsFailure() => l10n.loginInvalidCredentials,
    EmailTakenFailure() => l10n.registerEmailTaken,
    ValidationFailure() => l10n.errorValidation,
    RateLimitedFailure(:final retryAfter) => _rateLimited(l10n, retryAfter),
    UnauthorizedFailure(:final kind) => switch (kind) {
      UnauthorizedKind.tokenReused => l10n.errorSessionReused,
      _ => l10n.errorSessionExpired,
    },
    ForbiddenFailure() => l10n.errorForbidden,
    NotFoundFailure() => l10n.errorNotFound,
    GoneFailure() => l10n.errorUnknown,
    BusyFailure() => l10n.errorBusy,
    NetworkFailure(:final kind) => switch (kind) {
      NetworkFailureKind.offline => l10n.errorNetworkOffline,
      NetworkFailureKind.timeout => l10n.errorNetworkTimeout,
    },
    UnknownFailure() => l10n.errorUnknown,
  };
}

String _rateLimited(AppLocalizations l10n, Duration? retryAfter) {
  if (retryAfter == null || retryAfter.inSeconds <= 0) {
    return l10n.errorRateLimited;
  }
  final seconds = retryAfter.inSeconds;
  if (seconds < _secondsPerMinute) {
    return l10n.errorRateLimitedSeconds(seconds);
  }
  return l10n.errorRateLimitedMinutes(
    (seconds + _secondsPerMinute - 1) ~/ _secondsPerMinute,
  );
}

String apiFailureCode(ApiFailure failure) {
  return switch (failure) {
    InvalidCredentialsFailure() => 'invalid_credentials',
    EmailTakenFailure() => 'email_taken',
    ValidationFailure() => 'validation_error',
    RateLimitedFailure() => 'rate_limited',
    UnauthorizedFailure() => 'unauthorized',
    ForbiddenFailure() => 'forbidden',
    NotFoundFailure() => 'not_found',
    GoneFailure() => 'gone',
    BusyFailure() => 'busy',
    NetworkFailure(:final kind) => switch (kind) {
      NetworkFailureKind.offline => 'network_offline',
      NetworkFailureKind.timeout => 'network_timeout',
    },
    UnknownFailure(:final code, :final statusCode) =>
      code ?? (statusCode == null ? 'unknown' : 'http_$statusCode'),
  };
}
