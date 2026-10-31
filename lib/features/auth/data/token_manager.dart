import 'dart:async';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_policy.dart';
import '../../../core/result/result.dart';
import '../domain/auth_tokens.dart';
import '../domain/session.dart';
import '../domain/token_store.dart';
import 'auth_api.dart';

sealed class RefreshOutcome {
  const RefreshOutcome();
}

final class Refreshed extends RefreshOutcome {
  const Refreshed(this.tokens);

  final AuthTokens tokens;
}

final class SessionEnded extends RefreshOutcome {
  const SessionEnded(this.reason);

  final SignOutReason reason;
}

final class RefreshFailed extends RefreshOutcome {
  const RefreshFailed(this.failure);

  final ApiFailure failure;
}

final class NoCredential extends RefreshOutcome {
  const NoCredential();
}

class TokenManager {
  TokenManager({
    required this._store,
    required this._api,
    required this._now,
    this.leeway = ApiPolicy.proactiveRefreshLeeway,
  });

  final TokenStore _store;
  final AuthApi _api;
  final DateTime Function() _now;
  final Duration leeway;
  final StreamController<SignOutReason> _ended =
      StreamController<SignOutReason>.broadcast();

  AuthTokens? _tokens;
  Future<RefreshOutcome>? _inFlight;
  int _inFlightGeneration = 0;
  int _generation = 0;

  Stream<SignOutReason> get sessionEnds => _ended.stream;

  String? get currentRefreshToken => _tokens?.refresh;

  String? get currentAccessToken => _tokens?.access;

  Future<void> adopt(AuthTokens tokens) async {
    _generation++;
    _tokens = tokens;
    await _persist(tokens.refreshCredential);
  }

  Future<String?> accessToken() async {
    final tokens = _tokens;
    if (tokens == null) {
      return null;
    }
    if (tokens.accessNeedsRefresh(_now(), leeway)) {
      await refresh();
    }
    return _tokens?.access;
  }

  Future<RefreshOutcome> refresh({String? staleAccess}) {
    final current = _tokens;
    if (staleAccess != null &&
        current != null &&
        current.access != staleAccess) {
      return Future<RefreshOutcome>.value(Refreshed(current));
    }
    final running = _inFlight;
    if (running != null && _inFlightGeneration == _generation) {
      return running;
    }
    final future = _runRefresh();
    _inFlight = future;
    _inFlightGeneration = _generation;
    unawaited(
      future.whenComplete(() {
        if (identical(_inFlight, future)) {
          _inFlight = null;
        }
      }),
    );
    return future;
  }

  Future<void> endSession(SignOutReason reason) async {
    await clear();
    if (!_ended.isClosed) {
      _ended.add(reason);
    }
  }

  Future<void> clear() async {
    _generation++;
    _tokens = null;
    try {
      await _store.clear();
    } on Exception {
      return;
    }
  }

  Future<void> dispose() => _ended.close();

  Future<RefreshOutcome> _runRefresh() async {
    final generation = _generation;
    final String token;
    final inMemory = _tokens;
    if (inMemory != null) {
      token = inMemory.refresh;
    } else {
      final stored = await _readStored();
      if (generation != _generation) {
        return const NoCredential();
      }
      if (stored == null) {
        return const NoCredential();
      }
      token = stored.token;
    }
    final result = await _api.refresh(token);
    if (generation != _generation) {
      return const NoCredential();
    }
    switch (result) {
      case Success<AuthTokens, ApiFailure>(:final value):
        _tokens = value;
        await _persist(value.refreshCredential);
        return Refreshed(value);
      case Failure<AuthTokens, ApiFailure>(:final failure):
        if (_endsSession(failure)) {
          final reason = _reasonFor(failure);
          await endSession(reason);
          return SessionEnded(reason);
        }
        return RefreshFailed(failure);
    }
  }

  bool _endsSession(ApiFailure failure) {
    return failure is UnauthorizedFailure || failure is ValidationFailure;
  }

  SignOutReason _reasonFor(ApiFailure failure) {
    return failure is UnauthorizedFailure &&
            failure.kind == UnauthorizedKind.tokenReused
        ? SignOutReason.reused
        : SignOutReason.expired;
  }

  Future<RefreshCredential?> _readStored() async {
    try {
      return await _store.read();
    } on Exception {
      return null;
    }
  }

  Future<void> _persist(RefreshCredential credential) async {
    try {
      await _store.write(credential);
    } on Exception {
      return;
    }
  }
}
