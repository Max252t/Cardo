import 'package:dio/dio.dart';

import '../../../core/network/api_call.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_policy.dart';
import '../../../core/result/result.dart';
import '../domain/auth_tokens.dart';
import '../domain/user.dart';
import 'auth_api.dart';
import 'auth_dto.dart';

class DioAuthApi implements AuthApi {
  DioAuthApi(this._dio, {this._now = DateTime.now});

  final Dio _dio;
  final DateTime Function() _now;

  @override
  Future<Result<AuthGrant, ApiFailure>> register({
    required String email,
    required String password,
    required String displayName,
    String? avatarColor,
  }) {
    return apiCall(() async {
      final response = await _dio.post<dynamic>(
        ApiPaths.register,
        data: <String, Object>{
          'email': email,
          'password': password,
          'display_name': displayName,
          'avatar_color': ?avatarColor,
        },
      );
      return grantFromJson(response.data, now: _now());
    });
  }

  @override
  Future<Result<AuthGrant, ApiFailure>> login({
    required String email,
    required String password,
  }) {
    return apiCall(() async {
      final response = await _dio.post<dynamic>(
        ApiPaths.login,
        data: <String, String>{'email': email, 'password': password},
      );
      return grantFromJson(response.data, now: _now());
    });
  }

  @override
  Future<Result<AuthTokens, ApiFailure>> refresh(String refreshToken) {
    return apiCall(() async {
      final response = await _dio.post<dynamic>(
        ApiPaths.refresh,
        data: <String, String>{'refresh_token': refreshToken},
      );
      return tokensFromJson(response.data, now: _now());
    });
  }

  @override
  Future<Result<void, ApiFailure>> logout(String refreshToken) {
    return apiCall(() async {
      await _dio.post<dynamic>(
        ApiPaths.logout,
        data: <String, String>{'refresh_token': refreshToken},
      );
    });
  }

  @override
  Future<Result<User, ApiFailure>> getMe() {
    return apiCall(() async {
      final response = await _dio.get<dynamic>(ApiPaths.me);
      return userFromJson(response.data);
    });
  }

  @override
  Future<Result<User, ApiFailure>> updateMe({
    String? displayName,
    String? avatarColor,
  }) {
    return apiCall(() async {
      final response = await _dio.patch<dynamic>(
        ApiPaths.me,
        data: <String, String>{
          'display_name': ?displayName,
          'avatar_color': ?avatarColor,
        },
      );
      return userFromJson(response.data);
    });
  }
}
