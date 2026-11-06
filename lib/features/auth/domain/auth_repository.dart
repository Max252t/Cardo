import '../../../core/network/api_failure.dart';
import '../../../core/result/result.dart';
import 'session.dart';
import 'user.dart';

sealed class RestoreOutcome {
  const RestoreOutcome();
}

final class Restored extends RestoreOutcome {
  const Restored(this.user);

  final User user;
}

final class NoSession extends RestoreOutcome {
  const NoSession({this.reason});

  final SignOutReason? reason;
}

final class RestoreUnavailable extends RestoreOutcome {
  const RestoreUnavailable(this.failure);

  final ApiFailure failure;
}

abstract interface class AuthRepository {
  Stream<SignOutReason> get forcedSignOuts;

  Future<RestoreOutcome> restore();

  Future<Result<User, ApiFailure>> login({
    required String email,
    required String password,
  });

  Future<Result<User, ApiFailure>> register({
    required String email,
    required String password,
    required String displayName,
    String? avatarColor,
  });

  Future<Result<User, ApiFailure>> updateProfile({
    String? displayName,
    String? avatarColor,
  });

  Future<void> logout();
}
