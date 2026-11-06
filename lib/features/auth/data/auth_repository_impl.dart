import '../../../core/network/api_failure.dart';
import '../../../core/result/result.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_tokens.dart';
import '../domain/session.dart';
import '../domain/user.dart';
import 'auth_api.dart';
import 'token_manager.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required this._api, required this._tokens});

  final AuthApi _api;
  final TokenManager _tokens;

  @override
  Stream<SignOutReason> get forcedSignOuts => _tokens.sessionEnds;

  @override
  Future<RestoreOutcome> restore() async {
    final outcome = await _tokens.refresh();
    switch (outcome) {
      case NoCredential():
        return const NoSession();
      case SessionEnded(:final reason):
        return NoSession(reason: reason);
      case RefreshFailed(:final failure):
        return RestoreUnavailable(failure);
      case Refreshed():
        final me = await _api.getMe();
        switch (me) {
          case Success<User, ApiFailure>(:final value):
            return Restored(value);
          case Failure<User, ApiFailure>(:final failure):
            if (failure is UnauthorizedFailure) {
              await _tokens.endSession(SignOutReason.expired);
              return const NoSession(reason: SignOutReason.expired);
            }
            return RestoreUnavailable(failure);
        }
    }
  }

  @override
  Future<Result<User, ApiFailure>> login({
    required String email,
    required String password,
  }) async {
    return _adopt(await _api.login(email: email, password: password));
  }

  @override
  Future<Result<User, ApiFailure>> register({
    required String email,
    required String password,
    required String displayName,
    String? avatarColor,
  }) async {
    return _adopt(
      await _api.register(
        email: email,
        password: password,
        displayName: displayName,
        avatarColor: avatarColor,
      ),
    );
  }

  @override
  Future<Result<User, ApiFailure>> updateProfile({
    String? displayName,
    String? avatarColor,
  }) {
    return _api.updateMe(displayName: displayName, avatarColor: avatarColor);
  }

  @override
  Future<void> logout() async {
    final refresh = _tokens.currentRefreshToken;
    try {
      if (refresh != null) {
        await _api.logout(refresh);
      }
    } finally {
      await _tokens.clear();
    }
  }

  Future<Result<User, ApiFailure>> _adopt(
    Result<AuthGrant, ApiFailure> result,
  ) async {
    switch (result) {
      case Success<AuthGrant, ApiFailure>(:final value):
        await _tokens.adopt(value.tokens);
        return Success<User, ApiFailure>(value.user);
      case Failure<AuthGrant, ApiFailure>(:final failure):
        return Failure<User, ApiFailure>(failure);
    }
  }
}
