import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/result/result.dart';
import '../../../shared/providers/app_config_provider.dart';
import '../domain/auth_repository.dart';
import '../domain/session.dart';
import '../domain/user.dart';
import 'auth_providers.dart';

class SessionNotifier extends Notifier<Session> {
  @override
  Session build() {
    if (!ref.watch(appConfigProvider).isValid) {
      return const SessionSignedOut();
    }
    final repository = ref.watch(authRepositoryProvider);
    final subscription = repository.forcedSignOuts.listen(_onForcedSignOut);
    ref.onDispose(subscription.cancel);
    unawaited(Future<void>.microtask(_restore));
    return const SessionRestoring();
  }

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  Future<void> retryRestore() {
    state = const SessionRestoring();
    return _restore();
  }

  Future<Result<User, ApiFailure>> signIn({
    required String email,
    required String password,
  }) async {
    final result = await _repository.login(email: email, password: password);
    return _enter(result);
  }

  Future<Result<User, ApiFailure>> register({
    required String email,
    required String password,
    required String displayName,
    String? avatarColor,
  }) async {
    final result = await _repository.register(
      email: email,
      password: password,
      displayName: displayName,
      avatarColor: avatarColor,
    );
    return _enter(result);
  }

  Future<Result<User, ApiFailure>> updateProfile({
    String? displayName,
    String? avatarColor,
  }) async {
    final result = await _repository.updateProfile(
      displayName: displayName,
      avatarColor: avatarColor,
    );
    if (ref.mounted && result is Success<User, ApiFailure>) {
      state = SessionSignedIn(result.value);
    }
    return result;
  }

  Future<void> signOut() async {
    await _repository.logout();
    if (ref.mounted) {
      state = const SessionSignedOut();
    }
  }

  Result<User, ApiFailure> _enter(Result<User, ApiFailure> result) {
    if (ref.mounted && result is Success<User, ApiFailure>) {
      state = SessionSignedIn(result.value);
    }
    return result;
  }

  Future<void> _restore() async {
    final outcome = await _repository.restore();
    if (!ref.mounted) {
      return;
    }
    state = switch (outcome) {
      Restored(:final user) => SessionSignedIn(user),
      NoSession(:final reason) => SessionSignedOut(reason: reason),
      RestoreUnavailable() => const SessionUnavailable(),
    };
  }

  void _onForcedSignOut(SignOutReason reason) {
    if (!ref.mounted) {
      return;
    }
    state = SessionSignedOut(reason: reason);
  }
}
