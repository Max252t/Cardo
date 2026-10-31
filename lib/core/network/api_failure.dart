enum ErrorCode {
  badRequest('bad_request'),
  validationError('validation_error'),
  unauthorized('unauthorized'),
  invalidToken('invalid_token'),
  tokenExpired('token_expired'),
  tokenReused('token_reused'),
  invalidCredentials('invalid_credentials'),
  forbidden('forbidden'),
  notFound('not_found'),
  methodNotAllowed('method_not_allowed'),
  emailTaken('email_taken'),
  payloadTooLarge('payload_too_large'),
  rateLimited('rate_limited'),
  notReady('not_ready'),
  overloaded('overloaded'),
  busy('busy'),
  shuttingDown('shutting_down'),
  gone('gone'),
  alreadyMember('already_member'),
  inviteUnavailable('invite_unavailable'),
  internal('internal');

  const ErrorCode(this.wireName);

  final String wireName;

  static ErrorCode? tryParse(String? value) {
    for (final code in values) {
      if (code.wireName == value) {
        return code;
      }
    }
    return null;
  }
}

enum UnauthorizedKind { missing, invalidToken, tokenExpired, tokenReused }

enum NetworkFailureKind { offline, timeout }

sealed class ApiFailure {
  const ApiFailure();
}

final class InvalidCredentialsFailure extends ApiFailure {
  const InvalidCredentialsFailure();

  @override
  bool operator ==(Object other) => other is InvalidCredentialsFailure;

  @override
  int get hashCode => (InvalidCredentialsFailure).hashCode;
}

final class EmailTakenFailure extends ApiFailure {
  const EmailTakenFailure();

  @override
  bool operator ==(Object other) => other is EmailTakenFailure;

  @override
  int get hashCode => (EmailTakenFailure).hashCode;
}

final class ValidationFailure extends ApiFailure {
  const ValidationFailure({this.message});

  final String? message;

  @override
  bool operator ==(Object other) =>
      other is ValidationFailure && other.message == message;

  @override
  int get hashCode => Object.hash(ValidationFailure, message);
}

final class RateLimitedFailure extends ApiFailure {
  const RateLimitedFailure({this.retryAfter});

  final Duration? retryAfter;

  @override
  bool operator ==(Object other) =>
      other is RateLimitedFailure && other.retryAfter == retryAfter;

  @override
  int get hashCode => Object.hash(RateLimitedFailure, retryAfter);
}

final class UnauthorizedFailure extends ApiFailure {
  const UnauthorizedFailure(this.kind);

  final UnauthorizedKind kind;

  @override
  bool operator ==(Object other) =>
      other is UnauthorizedFailure && other.kind == kind;

  @override
  int get hashCode => Object.hash(UnauthorizedFailure, kind);
}

final class ForbiddenFailure extends ApiFailure {
  const ForbiddenFailure();

  @override
  bool operator ==(Object other) => other is ForbiddenFailure;

  @override
  int get hashCode => (ForbiddenFailure).hashCode;
}

final class NotFoundFailure extends ApiFailure {
  const NotFoundFailure();

  @override
  bool operator ==(Object other) => other is NotFoundFailure;

  @override
  int get hashCode => (NotFoundFailure).hashCode;
}

final class GoneFailure extends ApiFailure {
  const GoneFailure();

  @override
  bool operator ==(Object other) => other is GoneFailure;

  @override
  int get hashCode => (GoneFailure).hashCode;
}

final class BusyFailure extends ApiFailure {
  const BusyFailure({this.retryAfter});

  final Duration? retryAfter;

  @override
  bool operator ==(Object other) =>
      other is BusyFailure && other.retryAfter == retryAfter;

  @override
  int get hashCode => Object.hash(BusyFailure, retryAfter);
}

final class NetworkFailure extends ApiFailure {
  const NetworkFailure(this.kind);

  final NetworkFailureKind kind;

  @override
  bool operator ==(Object other) =>
      other is NetworkFailure && other.kind == kind;

  @override
  int get hashCode => Object.hash(NetworkFailure, kind);
}

final class UnknownFailure extends ApiFailure {
  const UnknownFailure({this.statusCode, this.code});

  final int? statusCode;
  final String? code;

  @override
  bool operator ==(Object other) =>
      other is UnknownFailure &&
      other.statusCode == statusCode &&
      other.code == code;

  @override
  int get hashCode => Object.hash(UnknownFailure, statusCode, code);
}
