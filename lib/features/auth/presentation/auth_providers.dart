import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_factory.dart';
import '../../../shared/providers/app_config_provider.dart';
import '../../../shared/time/now_provider.dart';
import '../data/auth_api.dart';
import '../data/auth_interceptor.dart';
import '../data/auth_repository_impl.dart';
import '../data/dio_auth_api.dart';
import '../data/secure_token_store.dart';
import '../data/token_manager.dart';
import '../domain/auth_repository.dart';
import '../domain/session.dart';
import '../domain/token_store.dart';
import '../domain/user.dart';
import 'session_notifier.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

Dio _newDio(Ref ref) {
  final base = ref.watch(appConfigProvider).apiBaseUri;
  if (base == null) {
    throw StateError('API base URL is not configured');
  }
  final dio = createDio(base, adapter: ref.watch(dioAdapterProvider));
  ref.onDispose(() => dio.close(force: true));
  return dio;
}

final Provider<Dio> rawDioProvider = Provider<Dio>(_newDio);

final Provider<Dio> dioProvider = Provider<Dio>((ref) {
  final dio = _newDio(ref);
  dio.interceptors.add(
    AuthInterceptor(dio: dio, tokens: () => ref.read(tokenManagerProvider)),
  );
  return dio;
});

final Provider<AuthApi> refreshApiProvider = Provider<AuthApi>(
  (ref) => DioAuthApi(ref.watch(rawDioProvider), now: ref.watch(nowProvider)),
);

final Provider<AuthApi> authApiProvider = Provider<AuthApi>(
  (ref) => DioAuthApi(ref.watch(dioProvider), now: ref.watch(nowProvider)),
);

final Provider<TokenManager> tokenManagerProvider = Provider<TokenManager>((
  ref,
) {
  final manager = TokenManager(
    store: ref.watch(tokenStoreProvider),
    api: ref.watch(refreshApiProvider),
    now: ref.watch(nowProvider),
  );
  ref.onDispose(manager.dispose);
  return manager;
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    api: ref.watch(authApiProvider),
    tokens: ref.watch(tokenManagerProvider),
  ),
);

final sessionProvider = NotifierProvider<SessionNotifier, Session>(
  SessionNotifier.new,
);

final sessionUserProvider = Provider<User?>((ref) {
  final session = ref.watch(sessionProvider);
  return session is SessionSignedIn ? session.user : null;
});
