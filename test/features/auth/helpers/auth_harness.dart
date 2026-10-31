import 'dart:async';

import 'package:cardo/core/network/api_policy.dart';
import 'package:cardo/core/network/dio_factory.dart';
import 'package:cardo/features/auth/data/auth_interceptor.dart';
import 'package:cardo/features/auth/data/dio_auth_api.dart';
import 'package:cardo/features/auth/data/token_manager.dart';
import 'package:cardo/features/auth/domain/auth_tokens.dart';
import 'package:cardo/features/auth/domain/session.dart';
import 'package:dio/dio.dart';

import '../../../helpers/api_json.dart';
import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/memory_token_store.dart';

final Uri testBaseUri = Uri.parse('http://api.test');

class AuthHarness {
  AuthHarness({DateTime? start}) : clock = start ?? t0 {
    store = MemoryTokenStore();
    adapter = FakeHttpAdapter(_handle);
    raw = createDio(testBaseUri, adapter: adapter);
    dio = createDio(testBaseUri, adapter: adapter);
    manager = TokenManager(
      store: store,
      api: DioAuthApi(raw),
      now: () => clock,
    );
    dio.interceptors.add(AuthInterceptor(dio: dio, tokens: () => manager));
    endings = <SignOutReason>[];
    manager.sessionEnds.listen(endings.add);
  }

  DateTime clock;
  late final MemoryTokenStore store;
  late final FakeHttpAdapter adapter;
  late final Dio raw;
  late final Dio dio;
  late final TokenManager manager;
  late final List<SignOutReason> endings;

  final Set<String> acceptedAccess = <String>{};
  Completer<void>? refreshGate;
  FutureOr<FakeResponse> Function(RequestOptions options)? refreshOverride;
  FutureOr<FakeResponse> Function(RequestOptions options)? protectedOverride;
  int issued = 0;

  AuthTokens tokens({
    String access = 'old',
    String refresh = 'refresh-0',
    Duration accessLeft = const Duration(minutes: 10),
    Duration refreshLeft = const Duration(days: 10),
    bool accepted = false,
  }) {
    if (accepted) {
      acceptedAccess.add(access);
    }
    return AuthTokens(
      access: access,
      accessExpiresAt: clock.add(accessLeft),
      refresh: refresh,
      refreshExpiresAt: clock.add(refreshLeft),
    );
  }

  Future<void> signIn(AuthTokens value) => manager.adopt(value);

  Future<Response<dynamic>> getBoards() => dio.get<dynamic>(ApiPaths.boards);

  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<FakeResponse> _handle(RequestOptions options) async {
    switch (options.path) {
      case ApiPaths.refresh:
        final gate = refreshGate;
        if (gate != null) {
          await gate.future;
        }
        final override = refreshOverride;
        if (override != null) {
          return override(options);
        }
        issued++;
        final access = 'access-$issued';
        acceptedAccess.add(access);
        return FakeResponse.ok(
          tokenJson(
            access: access,
            refresh: 'refresh-$issued',
            accessExpiresAt: clock.add(const Duration(minutes: 15)),
            refreshExpiresAt: clock.add(const Duration(days: 30)),
          ),
        );
      case ApiPaths.boards:
      case ApiPaths.me:
      case ApiPaths.logout:
        final override = protectedOverride;
        if (override != null) {
          return override(options);
        }
        final auth = options.headers['Authorization'];
        final accepted = acceptedAccess.any((token) => auth == 'Bearer $token');
        if (!accepted) {
          return FakeResponse.error(401, 'token_expired');
        }
        if (options.path == ApiPaths.logout) {
          return FakeResponse.empty(204);
        }
        return options.path == ApiPaths.me
            ? FakeResponse.ok(userJson())
            : FakeResponse.ok(boardListJson(const <Map<String, Object?>>[]));
      default:
        return FakeResponse.ok(<String, Object?>{'status': 'ok'});
    }
  }
}
