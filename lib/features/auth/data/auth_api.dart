import '../../../core/network/api_failure.dart';
import '../../../core/result/result.dart';
import '../domain/auth_tokens.dart';
import '../domain/user.dart';

abstract interface class AuthApi {
  Future<Result<AuthGrant, ApiFailure>> register({
    required String email,
    required String password,
    required String displayName,
    String? avatarColor,
  });

  Future<Result<AuthGrant, ApiFailure>> login({
    required String email,
    required String password,
  });

  Future<Result<AuthTokens, ApiFailure>> refresh(String refreshToken);

  Future<Result<void, ApiFailure>> logout(String refreshToken);

  Future<Result<User, ApiFailure>> getMe();

  Future<Result<User, ApiFailure>> updateMe({
    String? displayName,
    String? avatarColor,
  });
}
