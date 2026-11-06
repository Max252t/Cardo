import 'package:cardo/core/network/api_failure.dart';
import 'package:cardo/core/result/result.dart';
import 'package:cardo/features/auth/data/auth_api.dart';
import 'package:cardo/features/auth/data/auth_dto.dart';
import 'package:cardo/features/auth/domain/auth_tokens.dart';
import 'package:cardo/features/auth/domain/user.dart';

import '../../../helpers/api_json.dart';

User sampleUser({String name = 'Anna'}) =>
    userFromJson(userJson(displayName: name));

AuthTokens sampleTokens({
  String access = 'access-x',
  String refresh = 'refresh-x',
}) => tokensFromJson(
  tokenJson(access: access, refresh: refresh),
  now: DateTime.utc(2026, 3, 1, 12),
);

class FakeAuthApi implements AuthApi {
  Result<AuthGrant, ApiFailure>? loginResult;
  Result<AuthGrant, ApiFailure>? registerResult;
  Result<AuthTokens, ApiFailure>? refreshResult;
  Result<void, ApiFailure> logoutResult = const Success<void, ApiFailure>(null);
  Result<User, ApiFailure>? meResult;
  Result<User, ApiFailure>? updateResult;

  final List<String> calls = <String>[];
  final List<Map<String, Object?>> args = <Map<String, Object?>>[];

  @override
  Future<Result<AuthGrant, ApiFailure>> login({
    required String email,
    required String password,
  }) async {
    calls.add('login');
    args.add(<String, Object?>{'email': email, 'password': password});
    return loginResult ??
        const Failure<AuthGrant, ApiFailure>(UnknownFailure());
  }

  @override
  Future<Result<AuthGrant, ApiFailure>> register({
    required String email,
    required String password,
    required String displayName,
    String? avatarColor,
  }) async {
    calls.add('register');
    args.add(<String, Object?>{
      'email': email,
      'password': password,
      'displayName': displayName,
      'avatarColor': avatarColor,
    });
    return registerResult ??
        const Failure<AuthGrant, ApiFailure>(UnknownFailure());
  }

  @override
  Future<Result<AuthTokens, ApiFailure>> refresh(String refreshToken) async {
    calls.add('refresh');
    args.add(<String, Object?>{'refresh': refreshToken});
    return refreshResult ??
        const Failure<AuthTokens, ApiFailure>(UnknownFailure());
  }

  @override
  Future<Result<void, ApiFailure>> logout(String refreshToken) async {
    calls.add('logout');
    args.add(<String, Object?>{'refresh': refreshToken});
    return logoutResult;
  }

  @override
  Future<Result<User, ApiFailure>> getMe() async {
    calls.add('getMe');
    return meResult ?? const Failure<User, ApiFailure>(UnknownFailure());
  }

  @override
  Future<Result<User, ApiFailure>> updateMe({
    String? displayName,
    String? avatarColor,
  }) async {
    calls.add('updateMe');
    args.add(<String, Object?>{
      'displayName': displayName,
      'avatarColor': avatarColor,
    });
    return updateResult ?? const Failure<User, ApiFailure>(UnknownFailure());
  }
}
