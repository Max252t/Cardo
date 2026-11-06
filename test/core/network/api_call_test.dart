import 'package:cardo/core/network/api_call.dart';
import 'package:cardo/core/network/api_failure.dart';
import 'package:cardo/core/network/api_policy.dart';
import 'package:cardo/core/network/dio_factory.dart';
import 'package:cardo/core/result/result.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http_adapter.dart';

const List<String> openapiErrorCodes = <String>[
  'bad_request',
  'validation_error',
  'unauthorized',
  'invalid_token',
  'token_expired',
  'token_reused',
  'invalid_credentials',
  'forbidden',
  'not_found',
  'method_not_allowed',
  'email_taken',
  'payload_too_large',
  'rate_limited',
  'not_ready',
  'overloaded',
  'busy',
  'shutting_down',
  'gone',
  'already_member',
  'invite_unavailable',
  'internal',
];

Response<dynamic> responseOf(
  int status, {
  Object? data,
  Map<String, String> headers = const <String, String>{},
}) {
  return Response<dynamic>(
    requestOptions: RequestOptions(path: '/x'),
    statusCode: status,
    data: data,
    headers: Headers.fromMap(<String, List<String>>{
      for (final entry in headers.entries) entry.key: <String>[entry.value],
    }),
  );
}

Map<String, Object?> errorBody(String code, [String message = 'm']) =>
    <String, Object?>{
      'error': <String, Object?>{'code': code, 'message': message},
    };

DioException dioError(DioExceptionType type, {Response<dynamic>? response}) {
  return DioException(
    requestOptions: RequestOptions(path: '/x'),
    type: type,
    response: response,
  );
}

void main() {
  group('ErrorCode', () {
    test('covers exactly the codes of the openapi enum', () {
      expect(
        ErrorCode.values.map((code) => code.wireName).toList(),
        openapiErrorCodes,
      );
    });

    test('tryParse resolves wire names and rejects everything else', () {
      for (final name in openapiErrorCodes) {
        expect(ErrorCode.tryParse(name)?.wireName, name);
      }
      expect(ErrorCode.tryParse(null), isNull);
      expect(ErrorCode.tryParse(''), isNull);
      expect(ErrorCode.tryParse('Rate_Limited'), isNull);
      expect(ErrorCode.tryParse('teapot'), isNull);
    });
  });

  group('failureFromResponse: every openapi code', () {
    final expected = <String, ApiFailure>{
      'bad_request': const ValidationFailure(message: 'm'),
      'validation_error': const ValidationFailure(message: 'm'),
      'unauthorized': const UnauthorizedFailure(UnauthorizedKind.missing),
      'invalid_token': const UnauthorizedFailure(UnauthorizedKind.invalidToken),
      'token_expired': const UnauthorizedFailure(UnauthorizedKind.tokenExpired),
      'token_reused': const UnauthorizedFailure(UnauthorizedKind.tokenReused),
      'invalid_credentials': const InvalidCredentialsFailure(),
      'forbidden': const ForbiddenFailure(),
      'not_found': const NotFoundFailure(),
      'method_not_allowed': const UnknownFailure(
        statusCode: 400,
        code: 'method_not_allowed',
      ),
      'email_taken': const EmailTakenFailure(),
      'payload_too_large': const ValidationFailure(message: 'm'),
      'rate_limited': const RateLimitedFailure(),
      'not_ready': const BusyFailure(),
      'overloaded': const BusyFailure(),
      'busy': const BusyFailure(),
      'shutting_down': const BusyFailure(),
      'gone': const GoneFailure(),
      'already_member': const UnknownFailure(
        statusCode: 400,
        code: 'already_member',
      ),
      'invite_unavailable': const UnknownFailure(
        statusCode: 400,
        code: 'invite_unavailable',
      ),
      'internal': const UnknownFailure(statusCode: 400, code: 'internal'),
    };

    test('the table lists every code', () {
      expect(expected.keys.toList()..sort(), [...openapiErrorCodes]..sort());
    });

    for (final name in openapiErrorCodes) {
      test(name, () {
        final failure = failureFromResponse(
          responseOf(400, data: errorBody(name)),
        );

        expect(failure, expected[name]);
      });
    }
  });

  group('failureFromResponse: Retry-After', () {
    ApiFailure rateLimited(String? header, {String key = 'Retry-After'}) {
      return failureFromResponse(
        responseOf(
          429,
          data: errorBody('rate_limited'),
          headers: <String, String>{key: ?header},
        ),
      );
    }

    test('seconds as a number', () {
      expect(
        rateLimited('42'),
        const RateLimitedFailure(retryAfter: Duration(seconds: 42)),
      );
    });

    test('zero is kept as a zero duration', () {
      expect(
        rateLimited('0'),
        const RateLimitedFailure(retryAfter: Duration.zero),
      );
    });

    test('whitespace is trimmed', () {
      expect(
        rateLimited(' 7 '),
        const RateLimitedFailure(retryAfter: Duration(seconds: 7)),
      );
    });

    test('header name is case-insensitive', () {
      expect(
        rateLimited('5', key: 'retry-after'),
        const RateLimitedFailure(retryAfter: Duration(seconds: 5)),
      );
      expect(
        rateLimited('5', key: 'RETRY-AFTER'),
        const RateLimitedFailure(retryAfter: Duration(seconds: 5)),
      );
    });

    test('an HTTP date is not parsed and yields no duration', () {
      expect(
        rateLimited('Wed, 21 Oct 2026 07:28:00 GMT'),
        const RateLimitedFailure(),
      );
    });

    test('garbage, fractions and negatives yield no duration', () {
      for (final junk in <String>['soon', '', '1.5', '-3', '1e3', '12s']) {
        expect(rateLimited(junk), const RateLimitedFailure(), reason: junk);
      }
    });

    test('a missing header yields no duration', () {
      expect(rateLimited(null), const RateLimitedFailure());
    });

    test('busy family carries Retry-After as well', () {
      for (final code in <String>[
        'busy',
        'overloaded',
        'shutting_down',
        'not_ready',
      ]) {
        final failure = failureFromResponse(
          responseOf(
            503,
            data: errorBody(code),
            headers: <String, String>{'Retry-After': '9'},
          ),
        );
        expect(
          failure,
          const BusyFailure(retryAfter: Duration(seconds: 9)),
          reason: code,
        );
      }
    });

    test('other failures ignore Retry-After', () {
      final failure = failureFromResponse(
        responseOf(
          404,
          data: errorBody('not_found'),
          headers: <String, String>{'Retry-After': '9'},
        ),
      );
      expect(failure, const NotFoundFailure());
    });
  });

  group('failureFromResponse: malformed answers', () {
    test('an unknown code keeps status and code', () {
      expect(
        failureFromResponse(responseOf(418, data: errorBody('teapot'))),
        const UnknownFailure(statusCode: 418, code: 'teapot'),
      );
    });

    test('an empty body is unknown with the status', () {
      expect(
        failureFromResponse(responseOf(502)),
        const UnknownFailure(statusCode: 502),
      );
      expect(
        failureFromResponse(responseOf(502, data: '')),
        const UnknownFailure(statusCode: 502),
      );
    });

    test('a null response is unknown without status', () {
      expect(failureFromResponse(null), const UnknownFailure());
    });

    test('non-JSON text and wrong shapes are unknown', () {
      final shapes = <Object?>[
        '<html>bad gateway</html>',
        <Object?>[],
        42,
        <String, Object?>{'error': 'boom'},
        <String, Object?>{'error': <Object?>[]},
        <String, Object?>{'message': 'no envelope'},
        <String, Object?>{
          'error': <String, Object?>{'code': 7, 'message': 'x'},
        },
        <String, Object?>{
          'error': <String, Object?>{'message': 'x'},
        },
      ];
      for (final shape in shapes) {
        expect(
          failureFromResponse(responseOf(500, data: shape)),
          const UnknownFailure(statusCode: 500),
          reason: '$shape',
        );
      }
    });

    test('a non-string message is dropped, the code is still used', () {
      final failure = failureFromResponse(
        responseOf(
          400,
          data: <String, Object?>{
            'error': <String, Object?>{
              'code': 'validation_error',
              'message': 5,
            },
          },
        ),
      );
      expect(failure, const ValidationFailure());
    });

    test('a validation message is carried through', () {
      expect(
        failureFromResponse(
          responseOf(
            400,
            data: errorBody('validation_error', 'title too long'),
          ),
        ),
        const ValidationFailure(message: 'title too long'),
      );
    });
  });

  group('failureFromDio', () {
    test('timeouts and transform timeouts map to timeout', () {
      for (final type in <DioExceptionType>[
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(
          failureFromDio(dioError(type)),
          const NetworkFailure(NetworkFailureKind.timeout),
          reason: '$type',
        );
      }
    });

    test('a refused connection maps to offline', () {
      expect(
        failureFromDio(dioError(DioExceptionType.connectionError)),
        const NetworkFailure(NetworkFailureKind.offline),
      );
    });

    test('badResponse is decoded from the body', () {
      expect(
        failureFromDio(
          dioError(
            DioExceptionType.badResponse,
            response: responseOf(409, data: errorBody('email_taken')),
          ),
        ),
        const EmailTakenFailure(),
      );
    });

    test('certificate errors, cancels and unknown map to unknown', () {
      for (final type in <DioExceptionType>[
        DioExceptionType.badCertificate,
        DioExceptionType.cancel,
        DioExceptionType.unknown,
      ]) {
        expect(failureFromDio(dioError(type)), const UnknownFailure());
      }
    });

    test('a wrapped ApiFailure wins over the dio type', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.unknown,
        error: const NetworkFailure(NetworkFailureKind.offline),
      );
      expect(
        failureFromDio(error),
        const NetworkFailure(NetworkFailureKind.offline),
      );
    });
  });

  group('apiCall over a real Dio and a fake adapter', () {
    Dio dioWith(FakeResponse response) {
      return createDio(
        Uri.parse('http://api.test'),
        adapter: FakeHttpAdapter((options) => response),
      );
    }

    Future<Result<String, ApiFailure>> fetchId(Dio dio) {
      return apiCall(() async {
        final response = await dio.get<dynamic>('/api/x');
        return (response.data as Map<String, dynamic>)['id'] as String;
      });
    }

    test('a 2xx body is passed to the callback', () async {
      final result = await fetchId(
        dioWith(FakeResponse.ok(<String, Object?>{'id': 'a'})),
      );
      expect(result, const Success<String, ApiFailure>('a'));
    });

    test('connect timeout becomes a network failure', () async {
      final result = await fetchId(
        dioWith(FakeResponse.network(DioExceptionType.connectionTimeout)),
      );
      expect(
        result.failureOrNull,
        const NetworkFailure(NetworkFailureKind.timeout),
      );
    });

    test('receive timeout becomes a network failure', () async {
      final result = await fetchId(
        dioWith(FakeResponse.network(DioExceptionType.receiveTimeout)),
      );
      expect(
        result.failureOrNull,
        const NetworkFailure(NetworkFailureKind.timeout),
      );
    });

    test('missing connection becomes an offline failure', () async {
      final result = await fetchId(
        dioWith(FakeResponse.network(DioExceptionType.connectionError)),
      );
      expect(
        result.failureOrNull,
        const NetworkFailure(NetworkFailureKind.offline),
      );
    });

    test('a JSON error envelope is decoded by status family', () async {
      final result = await fetchId(
        dioWith(
          FakeResponse.error(
            429,
            'rate_limited',
            headers: <String, String>{'Retry-After': '30'},
          ),
        ),
      );
      expect(
        result.failureOrNull,
        const RateLimitedFailure(retryAfter: Duration(seconds: 30)),
      );
    });

    test('a 5xx with HTML is unknown with its status', () async {
      final result = await fetchId(
        dioWith(
          const FakeResponse(
            502,
            text: '<html>bad gateway</html>',
            headers: <String, String>{'content-type': 'text/html'},
          ),
        ),
      );
      expect(result.failureOrNull, const UnknownFailure(statusCode: 502));
    });

    test('a 5xx with an empty body is unknown with its status', () async {
      final result = await fetchId(dioWith(FakeResponse.empty(500)));
      expect(result.failureOrNull, const UnknownFailure(statusCode: 500));
    });

    test('a 5xx with HTML mislabelled as JSON is unknown', () async {
      final result = await fetchId(
        dioWith(const FakeResponse(502, text: '<html>bad gateway</html>')),
      );
      expect(result.failureOrNull, const UnknownFailure());
    });

    test('a 2xx with broken JSON is unknown', () async {
      final result = await fetchId(
        dioWith(const FakeResponse(200, text: '{"id": ')),
      );
      expect(result.failureOrNull, isA<ApiFailure>());
      expect(result.isSuccess, isFalse);
    });

    test('a 2xx with an empty body is unknown', () async {
      final result = await fetchId(dioWith(FakeResponse.empty(200)));
      expect(result.failureOrNull, const UnknownFailure());
    });

    test('a 2xx with a wrong shape (TypeError) is unknown', () async {
      final result = await fetchId(
        dioWith(FakeResponse.ok(<String, Object?>{'id': 5})),
      );
      expect(result.failureOrNull, const UnknownFailure());
    });

    test('a FormatException thrown by the callback is unknown', () async {
      final result = await apiCall<int>(() async {
        throw const FormatException('bad');
      });
      expect(result.failureOrNull, const UnknownFailure());
    });
  });

  group('createDio', () {
    test('applies the policy constants and the base url', () {
      final dio = createDio(Uri.parse('https://api.test:8443'));

      expect(dio.options.baseUrl, 'https://api.test:8443');
      expect(dio.options.connectTimeout, ApiPolicy.connectTimeout);
      expect(dio.options.sendTimeout, ApiPolicy.sendTimeout);
      expect(dio.options.receiveTimeout, ApiPolicy.receiveTimeout);
      expect(dio.options.contentType, Headers.jsonContentType);
      expect(
        dio.options.headers[Headers.acceptHeader],
        Headers.jsonContentType,
      );
    });

    test('uses the injected adapter', () {
      final adapter = FakeHttpAdapter();
      final dio = createDio(Uri.parse('http://api.test'), adapter: adapter);

      expect(dio.httpClientAdapter, same(adapter));
    });

    test('installs no logging interceptor', () {
      final dio = createDio(Uri.parse('http://api.test'));

      expect(dio.interceptors.whereType<LogInterceptor>(), isEmpty);
    });
  });

  group('Result', () {
    test('map and mapFailure transform only their side', () {
      const ok = Success<int, String>(2);
      const bad = Failure<int, String>('e');

      expect(ok.map((v) => v * 2), const Success<int, String>(4));
      expect(bad.map((v) => v * 2), const Failure<int, String>('e'));
      expect(ok.mapFailure((f) => '$f!'), ok);
      expect(bad.mapFailure((f) => '$f!'), const Failure<int, String>('e!'));
    });

    test('accessors', () {
      const ok = Success<int, String>(2);
      const bad = Failure<int, String>('e');

      expect(ok.isSuccess, isTrue);
      expect(bad.isSuccess, isFalse);
      expect(ok.valueOrNull, 2);
      expect(ok.failureOrNull, isNull);
      expect(bad.valueOrNull, isNull);
      expect(bad.failureOrNull, 'e');
    });

    test('equality, hashing and toString', () {
      expect(const Success<int, String>(1), const Success<int, String>(1));
      expect(
        const Success<int, String>(1).hashCode,
        const Success<int, String>(1).hashCode,
      );
      expect(
        const Success<int, String>(1) == const Success<int, String>(2),
        isFalse,
      );
      expect(const Failure<int, String>('a'), const Failure<int, String>('a'));
      expect(
        const Failure<int, String>('a').hashCode,
        const Failure<int, String>('a').hashCode,
      );
      expect(const Success<int, String>(1).toString(), 'Success(1)');
      expect(const Failure<int, String>('a').toString(), 'Failure(a)');
    });
  });

  group('ApiPaths', () {
    test('board encodes the id', () {
      expect(ApiPaths.board('a b/c'), '/api/boards/a%20b%2Fc');
    });
  });
}
