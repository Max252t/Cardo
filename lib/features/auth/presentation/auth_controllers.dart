import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/result/result.dart';
import '../domain/user.dart';
import 'auth_providers.dart';

@immutable
class AuthFormState {
  const AuthFormState({this.submitting = false, this.failure});

  final bool submitting;
  final ApiFailure? failure;

  @override
  bool operator ==(Object other) {
    return other is AuthFormState &&
        other.submitting == submitting &&
        other.failure == failure;
  }

  @override
  int get hashCode => Object.hash(submitting, failure);
}

abstract class AuthFormController extends Notifier<AuthFormState> {
  @override
  AuthFormState build() => const AuthFormState();

  void clearFailure() {
    if (state.failure != null && !state.submitting) {
      state = const AuthFormState();
    }
  }

  Future<bool> run(Future<Result<User, ApiFailure>> Function() action) async {
    if (state.submitting) {
      return false;
    }
    state = const AuthFormState(submitting: true);
    final result = await action();
    if (!ref.mounted) {
      return result.isSuccess;
    }
    state = AuthFormState(failure: result.failureOrNull);
    return result.isSuccess;
  }
}

class LoginController extends AuthFormController {
  Future<bool> submit({required String email, required String password}) {
    return run(
      () => ref
          .read(sessionProvider.notifier)
          .signIn(email: email.trim(), password: password),
    );
  }
}

class RegisterController extends AuthFormController {
  Future<bool> submit({
    required String email,
    required String password,
    required String displayName,
    String? avatarColor,
  }) {
    return run(
      () => ref
          .read(sessionProvider.notifier)
          .register(
            email: email.trim(),
            password: password,
            displayName: displayName.trim(),
            avatarColor: avatarColor,
          ),
    );
  }
}

class ProfileController extends AuthFormController {
  Future<bool> submit({String? displayName, String? avatarColor}) {
    return run(
      () => ref
          .read(sessionProvider.notifier)
          .updateProfile(
            displayName: displayName?.trim(),
            avatarColor: avatarColor,
          ),
    );
  }
}

final loginControllerProvider =
    NotifierProvider.autoDispose<LoginController, AuthFormState>(
      LoginController.new,
    );

final registerControllerProvider =
    NotifierProvider.autoDispose<RegisterController, AuthFormState>(
      RegisterController.new,
    );

final profileControllerProvider =
    NotifierProvider.autoDispose<ProfileController, AuthFormState>(
      ProfileController.new,
    );
