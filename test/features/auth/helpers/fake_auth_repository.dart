import 'dart:async';

import 'package:cardo/core/network/api_failure.dart';
import 'package:cardo/core/result/result.dart';
import 'package:cardo/features/auth/domain/auth_repository.dart';
import 'package:cardo/features/auth/domain/session.dart';
import 'package:cardo/features/auth/domain/user.dart';

import 'fake_auth_api.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({RestoreOutcome? restore, User? user})
    : restoreOutcome = restore ?? const NoSession(),
      user = user ?? sampleUser();

  final StreamController<SignOutReason> forced =
      StreamController<SignOutReason>.broadcast();

  RestoreOutcome restoreOutcome;
  Completer<RestoreOutcome>? restoreGate;
  User user;
  Result<User, ApiFailure>? loginResult;
  Result<User, ApiFailure>? registerResult;
  Result<User, ApiFailure>? updateResult;
  Completer<void>? requestGate;
  Completer<void>? logoutGate;

  int restoreCalls = 0;
  int logoutCalls = 0;
  final List<Map<String, Object?>> logins = <Map<String, Object?>>[];
  final List<Map<String, Object?>> registers = <Map<String, Object?>>[];
  final List<Map<String, Object?>> updates = <Map<String, Object?>>[];

  @override
  Stream<SignOutReason> get forcedSignOuts => forced.stream;

  @override
  Future<RestoreOutcome> restore() async {
    restoreCalls++;
    final gate = restoreGate;
    if (gate != null) {
      return gate.future;
    }
    return restoreOutcome;
  }

  @override
  Future<Result<User, ApiFailure>> login({
    required String email,
    required String password,
  }) async {
    logins.add(<String, Object?>{'email': email, 'password': password});
    await requestGate?.future;
    return loginResult ?? Success<User, ApiFailure>(user);
  }

  @override
  Future<Result<User, ApiFailure>> register({
    required String email,
    required String password,
    required String displayName,
    String? avatarColor,
  }) async {
    registers.add(<String, Object?>{
      'email': email,
      'password': password,
      'displayName': displayName,
      'avatarColor': avatarColor,
    });
    await requestGate?.future;
    return registerResult ?? Success<User, ApiFailure>(user);
  }

  @override
  Future<Result<User, ApiFailure>> updateProfile({
    String? displayName,
    String? avatarColor,
  }) async {
    updates.add(<String, Object?>{
      'displayName': displayName,
      'avatarColor': avatarColor,
    });
    await requestGate?.future;
    return updateResult ??
        Success<User, ApiFailure>(
          user.copyWith(displayName: displayName, avatarColor: avatarColor),
        );
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    await logoutGate?.future;
  }

  Future<void> dispose() => forced.close();
}
