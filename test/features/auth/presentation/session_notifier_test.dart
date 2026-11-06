import 'dart:async';

import 'package:cardo/core/config/app_config.dart';
import 'package:cardo/core/network/api_failure.dart';
import 'package:cardo/core/result/result.dart';
import 'package:cardo/features/auth/domain/auth_repository.dart';
import 'package:cardo/features/auth/domain/session.dart';
import 'package:cardo/features/auth/domain/user.dart';
import 'package:cardo/features/auth/presentation/auth_controllers.dart';
import 'package:cardo/features/auth/presentation/auth_providers.dart';
import 'package:cardo/features/auth/presentation/session_notifier.dart';
import 'package:cardo/shared/providers/app_config_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_auth_api.dart';
import '../helpers/fake_auth_repository.dart';

Future<void> pump() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _Setup {
  _Setup({String config = 'http://api.test', FakeAuthRepository? repository})
    : repository = repository ?? FakeAuthRepository() {
    container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(AppConfig.parse(config)),
        authRepositoryProvider.overrideWithValue(this.repository),
      ],
    );
    container.listen<Session>(
      sessionProvider,
      (previous, next) => states.add(next),
      fireImmediately: true,
    );
  }

  final FakeAuthRepository repository;
  late final ProviderContainer container;
  final List<Session> states = <Session>[];

  SessionNotifier get notifier => container.read(sessionProvider.notifier);

  Session get state => container.read(sessionProvider);

  void dispose() {
    container.dispose();
    unawaited(repository.dispose());
  }
}

void main() {
  group('restore on start', () {
    test(
      'invalid config is signed out without touching the repository',
      () async {
        final setup = _Setup(config: '');
        addTearDown(setup.dispose);

        await pump();

        expect(setup.state, const SessionSignedOut());
        expect(setup.repository.restoreCalls, 0);
      },
    );

    test('starts restoring, then signs in with the restored user', () async {
      final setup = _Setup(
        repository: FakeAuthRepository(restore: Restored(sampleUser())),
      );
      addTearDown(setup.dispose);

      expect(setup.state, const SessionRestoring());
      await pump();

      expect(setup.states, <Session>[
        const SessionRestoring(),
        SessionSignedIn(sampleUser()),
      ]);
      expect(setup.repository.restoreCalls, 1);
    });

    test('no session means signed out without a reason', () async {
      final setup = _Setup();
      addTearDown(setup.dispose);

      await pump();

      expect(setup.state, const SessionSignedOut());
    });

    test('an expired session carries the reason', () async {
      final setup = _Setup(
        repository: FakeAuthRepository(
          restore: const NoSession(reason: SignOutReason.expired),
        ),
      );
      addTearDown(setup.dispose);

      await pump();

      expect(
        setup.state,
        const SessionSignedOut(reason: SignOutReason.expired),
      );
    });

    test('a reused token carries the reason', () async {
      final setup = _Setup(
        repository: FakeAuthRepository(
          restore: const NoSession(reason: SignOutReason.reused),
        ),
      );
      addTearDown(setup.dispose);

      await pump();

      expect(setup.state, const SessionSignedOut(reason: SignOutReason.reused));
    });

    test('an unreachable server is unavailable', () async {
      final setup = _Setup(
        repository: FakeAuthRepository(
          restore: const RestoreUnavailable(
            NetworkFailure(NetworkFailureKind.offline),
          ),
        ),
      );
      addTearDown(setup.dispose);

      await pump();

      expect(setup.state, const SessionUnavailable());
    });

    test('retryRestore goes back to restoring and then resolves', () async {
      final repository = FakeAuthRepository(
        restore: const RestoreUnavailable(
          NetworkFailure(NetworkFailureKind.timeout),
        ),
      );
      final setup = _Setup(repository: repository);
      addTearDown(setup.dispose);
      await pump();
      expect(setup.state, const SessionUnavailable());

      repository.restoreOutcome = Restored(sampleUser());
      final retry = setup.notifier.retryRestore();
      expect(setup.state, const SessionRestoring());
      await retry;

      expect(setup.state, SessionSignedIn(sampleUser()));
      expect(repository.restoreCalls, 2);
    });

    test('retryRestore can fail again', () async {
      final repository = FakeAuthRepository(
        restore: const RestoreUnavailable(UnknownFailure(statusCode: 500)),
      );
      final setup = _Setup(repository: repository);
      addTearDown(setup.dispose);
      await pump();

      await setup.notifier.retryRestore();

      expect(setup.state, const SessionUnavailable());
    });

    test('a restore finishing after dispose is ignored', () async {
      final repository = FakeAuthRepository()
        ..restoreGate = Completer<RestoreOutcome>();
      final setup = _Setup(repository: repository);
      await pump();

      setup.container.dispose();
      repository.restoreGate!.complete(Restored(sampleUser()));
      await pump();

      expect(setup.states, <Session>[const SessionRestoring()]);
      await repository.dispose();
    });
  });

  group('signIn, register, updateProfile', () {
    test('signIn success enters the signed-in state', () async {
      final setup = _Setup();
      addTearDown(setup.dispose);
      await pump();

      final result = await setup.notifier.signIn(
        email: 'a@b.co',
        password: 'password1',
      );

      expect(result, Success<User, ApiFailure>(sampleUser()));
      expect(setup.state, SessionSignedIn(sampleUser()));
      expect(setup.repository.logins.single, <String, Object?>{
        'email': 'a@b.co',
        'password': 'password1',
      });
    });

    test('signIn failure keeps the state and returns the failure', () async {
      final repository = FakeAuthRepository()
        ..loginResult = const Failure<User, ApiFailure>(
          InvalidCredentialsFailure(),
        );
      final setup = _Setup(repository: repository);
      addTearDown(setup.dispose);
      await pump();

      final result = await setup.notifier.signIn(
        email: 'a@b.co',
        password: 'bad',
      );

      expect(result.failureOrNull, const InvalidCredentialsFailure());
      expect(setup.state, const SessionSignedOut());
    });

    test('register passes the avatar color and enters signed-in', () async {
      final setup = _Setup();
      addTearDown(setup.dispose);
      await pump();

      await setup.notifier.register(
        email: 'a@b.co',
        password: 'password1',
        displayName: 'Anna',
        avatarColor: '#7C3AED',
      );

      expect(setup.state, SessionSignedIn(sampleUser()));
      expect(setup.repository.registers.single['avatarColor'], '#7C3AED');
    });

    test('register failure stays signed out', () async {
      final repository = FakeAuthRepository()
        ..registerResult = const Failure<User, ApiFailure>(EmailTakenFailure());
      final setup = _Setup(repository: repository);
      addTearDown(setup.dispose);
      await pump();

      final result = await setup.notifier.register(
        email: 'a@b.co',
        password: 'password1',
        displayName: 'Anna',
      );

      expect(result.failureOrNull, const EmailTakenFailure());
      expect(setup.state, const SessionSignedOut());
    });

    test('updateProfile replaces the user in the session', () async {
      final repository = FakeAuthRepository(restore: Restored(sampleUser()));
      final setup = _Setup(repository: repository);
      addTearDown(setup.dispose);
      await pump();

      await setup.notifier.updateProfile(displayName: 'Bea');

      expect(
        (setup.state as SessionSignedIn).user,
        sampleUser().copyWith(displayName: 'Bea'),
      );
    });

    test('updateProfile failure leaves the user alone', () async {
      final repository = FakeAuthRepository(restore: Restored(sampleUser()))
        ..updateResult = const Failure<User, ApiFailure>(ValidationFailure());
      final setup = _Setup(repository: repository);
      addTearDown(setup.dispose);
      await pump();

      await setup.notifier.updateProfile(displayName: 'Bea');

      expect(setup.state, SessionSignedIn(sampleUser()));
    });

    test('a sign-in finishing after dispose does not touch state', () async {
      final repository = FakeAuthRepository()..requestGate = Completer<void>();
      final setup = _Setup(repository: repository);
      await pump();

      final pending = setup.notifier.signIn(
        email: 'a@b.co',
        password: 'password1',
      );
      setup.container.dispose();
      repository.requestGate!.complete();
      final result = await pending;

      expect(result.isSuccess, isTrue);
      await repository.dispose();
    });
  });

  group('signOut and forced sign-out', () {
    test('signOut logs out and becomes signed out with no reason', () async {
      final repository = FakeAuthRepository(restore: Restored(sampleUser()));
      final setup = _Setup(repository: repository);
      addTearDown(setup.dispose);
      await pump();

      await setup.notifier.signOut();

      expect(repository.logoutCalls, 1);
      expect(setup.state, const SessionSignedOut());
    });

    test('the state changes only after the repository finished', () async {
      final repository = FakeAuthRepository(restore: Restored(sampleUser()))
        ..logoutGate = Completer<void>();
      final setup = _Setup(repository: repository);
      addTearDown(setup.dispose);
      await pump();

      final pending = setup.notifier.signOut();
      await pump();
      expect(setup.state, isA<SessionSignedIn>());

      repository.logoutGate!.complete();
      await pending;

      expect(setup.state, const SessionSignedOut());
    });

    for (final reason in SignOutReason.values) {
      test(
        'a forced sign-out with $reason is signed out with that reason',
        () async {
          final repository = FakeAuthRepository(
            restore: Restored(sampleUser()),
          );
          final setup = _Setup(repository: repository);
          addTearDown(setup.dispose);
          await pump();

          repository.forced.add(reason);
          await pump();

          expect(setup.state, SessionSignedOut(reason: reason));
        },
      );
    }

    test('forced sign-outs after dispose are ignored', () async {
      final repository = FakeAuthRepository(restore: Restored(sampleUser()));
      final setup = _Setup(repository: repository);
      await pump();
      final before = setup.states.length;

      setup.container.dispose();
      repository.forced.add(SignOutReason.expired);
      await pump();

      expect(setup.states.length, before);
      await repository.dispose();
    });

    test('sessionUserProvider follows the session', () async {
      final repository = FakeAuthRepository(restore: Restored(sampleUser()));
      final setup = _Setup(repository: repository);
      addTearDown(setup.dispose);
      expect(setup.container.read(sessionUserProvider), isNull);
      await pump();
      expect(setup.container.read(sessionUserProvider), sampleUser());

      repository.forced.add(SignOutReason.expired);
      await pump();

      expect(setup.container.read(sessionUserProvider), isNull);
    });
  });

  group('form controllers', () {
    test('a second submit while one is running is ignored', () async {
      final repository = FakeAuthRepository()..requestGate = Completer<void>();
      final setup = _Setup(repository: repository);
      addTearDown(setup.dispose);
      await pump();
      final subscription = setup.container.listen(
        loginControllerProvider,
        (previous, next) {},
      );
      addTearDown(subscription.close);
      final controller = setup.container.read(loginControllerProvider.notifier);

      final first = controller.submit(email: ' a@b.co ', password: 'password1');
      final second = await controller.submit(
        email: 'a@b.co',
        password: 'password1',
      );
      expect(second, isFalse);
      expect(setup.container.read(loginControllerProvider).submitting, isTrue);

      repository.requestGate!.complete();

      expect(await first, isTrue);
      expect(repository.logins, hasLength(1));
      expect(repository.logins.single['email'], 'a@b.co');
      expect(setup.container.read(loginControllerProvider).submitting, isFalse);
    });

    test('a failure is stored and clearFailure resets it', () async {
      final repository = FakeAuthRepository()
        ..loginResult = const Failure<User, ApiFailure>(
          InvalidCredentialsFailure(),
        );
      final setup = _Setup(repository: repository);
      addTearDown(setup.dispose);
      await pump();
      final subscription = setup.container.listen(
        loginControllerProvider,
        (previous, next) {},
      );
      addTearDown(subscription.close);
      final controller = setup.container.read(loginControllerProvider.notifier);

      final ok = await controller.submit(email: 'a@b.co', password: 'x');

      expect(ok, isFalse);
      expect(
        setup.container.read(loginControllerProvider).failure,
        const InvalidCredentialsFailure(),
      );

      controller.clearFailure();

      expect(setup.container.read(loginControllerProvider).failure, isNull);
    });

    test('register and profile controllers trim names', () async {
      final repository = FakeAuthRepository(restore: Restored(sampleUser()));
      final setup = _Setup(repository: repository);
      addTearDown(setup.dispose);
      await pump();
      final register = setup.container.listen(
        registerControllerProvider,
        (previous, next) {},
      );
      final profile = setup.container.listen(
        profileControllerProvider,
        (previous, next) {},
      );
      addTearDown(register.close);
      addTearDown(profile.close);

      await setup.container
          .read(registerControllerProvider.notifier)
          .submit(
            email: ' a@b.co ',
            password: ' keep spaces ',
            displayName: '  Anna  ',
          );
      await setup.container
          .read(profileControllerProvider.notifier)
          .submit(displayName: '  Bea ');

      expect(repository.registers.single['email'], 'a@b.co');
      expect(repository.registers.single['password'], ' keep spaces ');
      expect(repository.registers.single['displayName'], 'Anna');
      expect(repository.updates.single['displayName'], 'Bea');
    });
  });
}
