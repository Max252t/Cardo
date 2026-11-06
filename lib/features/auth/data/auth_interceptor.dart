import 'package:dio/dio.dart';

import '../../../core/network/api_call.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_policy.dart';
import '../domain/session.dart';
import 'token_manager.dart';

bool endsSessionOn401(String path) => path != ApiPaths.logout;

class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this._dio, required this._tokens});

  static const String _sentKey = 'cardo.sentAccessToken';
  static const String _retriedKey = 'cardo.authRetried';

  final Dio _dio;
  final TokenManager Function() _tokens;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (ApiPaths.public.contains(options.path)) {
      handler.next(options);
      return;
    }
    final access = options.path == ApiPaths.logout
        ? _tokens().currentAccessToken
        : await _tokens().accessToken();
    if (access != null) {
      options.headers[ApiPolicy.authorizationHeader] = 'Bearer $access';
      options.extra[_sentKey] = access;
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final sent = options.extra[_sentKey];
    if (ApiPaths.public.contains(options.path) ||
        sent is! String ||
        err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }
    final failure = failureFromResponse(err.response);
    if (failure is UnauthorizedFailure &&
        failure.kind == UnauthorizedKind.missing) {
      if (endsSessionOn401(options.path)) {
        await _tokens().endSession(SignOutReason.expired);
      }
      handler.next(err);
      return;
    }
    if (failure is! UnauthorizedFailure ||
        (failure.kind != UnauthorizedKind.tokenExpired &&
            failure.kind != UnauthorizedKind.invalidToken)) {
      handler.next(err);
      return;
    }
    final tokens = _tokens();
    if (options.extra[_retriedKey] == true) {
      if (endsSessionOn401(options.path)) {
        await tokens.endSession(SignOutReason.expired);
      }
      handler.next(err);
      return;
    }
    final outcome = await tokens.refresh(staleAccess: sent);
    switch (outcome) {
      case Refreshed():
        options.extra[_retriedKey] = true;
        if (options.path == ApiPaths.logout) {
          options.data = <String, String?>{
            'refresh_token': tokens.currentRefreshToken,
          };
        }
        try {
          handler.resolve(await _dio.fetch<dynamic>(options));
        } on DioException catch (retryError) {
          handler.next(retryError);
        }
      case RefreshFailed(:final failure):
        handler.next(
          DioException(
            requestOptions: options,
            type: DioExceptionType.unknown,
            error: failure,
          ),
        );
      case SessionEnded():
      case NoCredential():
        handler.next(err);
    }
  }
}
