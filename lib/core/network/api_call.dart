import 'package:dio/dio.dart';

import '../result/result.dart';
import 'api_failure.dart';

Future<Result<T, ApiFailure>> apiCall<T>(Future<T> Function() body) async {
  try {
    return Success<T, ApiFailure>(await body());
  } on DioException catch (error) {
    return Failure<T, ApiFailure>(failureFromDio(error));
  } on FormatException {
    return const Failure<Never, ApiFailure>(UnknownFailure());
  } on TypeError {
    return const Failure<Never, ApiFailure>(UnknownFailure());
  }
}

ApiFailure failureFromDio(DioException error) {
  final wrapped = error.error;
  if (wrapped is ApiFailure) {
    return wrapped;
  }
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const NetworkFailure(NetworkFailureKind.timeout);
    case DioExceptionType.connectionError:
      return const NetworkFailure(NetworkFailureKind.offline);
    case DioExceptionType.badResponse:
      return failureFromResponse(error.response);
    case DioExceptionType.badCertificate:
    case DioExceptionType.cancel:
    case DioExceptionType.unknown:
      return const UnknownFailure();
  }
}

ApiFailure failureFromResponse(Response<dynamic>? response) {
  final status = response?.statusCode;
  final body = response?.data;
  String? codeName;
  String? message;
  if (body is Map<String, dynamic>) {
    final inner = body['error'];
    if (inner is Map<String, dynamic>) {
      final code = inner['code'];
      final text = inner['message'];
      codeName = code is String ? code : null;
      message = text is String ? text : null;
    }
  }
  final retryAfter = _retryAfter(response?.headers.value('retry-after'));
  final code = ErrorCode.tryParse(codeName);
  switch (code) {
    case ErrorCode.invalidCredentials:
      return const InvalidCredentialsFailure();
    case ErrorCode.emailTaken:
      return const EmailTakenFailure();
    case ErrorCode.validationError:
    case ErrorCode.badRequest:
    case ErrorCode.payloadTooLarge:
      return ValidationFailure(message: message);
    case ErrorCode.rateLimited:
      return RateLimitedFailure(retryAfter: retryAfter);
    case ErrorCode.unauthorized:
      return const UnauthorizedFailure(UnauthorizedKind.missing);
    case ErrorCode.invalidToken:
      return const UnauthorizedFailure(UnauthorizedKind.invalidToken);
    case ErrorCode.tokenExpired:
      return const UnauthorizedFailure(UnauthorizedKind.tokenExpired);
    case ErrorCode.tokenReused:
      return const UnauthorizedFailure(UnauthorizedKind.tokenReused);
    case ErrorCode.forbidden:
      return const ForbiddenFailure();
    case ErrorCode.notFound:
      return const NotFoundFailure();
    case ErrorCode.gone:
      return const GoneFailure();
    case ErrorCode.busy:
    case ErrorCode.overloaded:
    case ErrorCode.shuttingDown:
    case ErrorCode.notReady:
      return BusyFailure(retryAfter: retryAfter);
    case ErrorCode.methodNotAllowed:
    case ErrorCode.alreadyMember:
    case ErrorCode.inviteUnavailable:
    case ErrorCode.internal:
    case null:
      return UnknownFailure(statusCode: status, code: codeName);
  }
}

Duration? _retryAfter(String? header) {
  if (header == null) {
    return null;
  }
  final seconds = int.tryParse(header.trim());
  if (seconds == null || seconds < 0) {
    return null;
  }
  return Duration(seconds: seconds);
}
