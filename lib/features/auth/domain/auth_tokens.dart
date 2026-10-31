import 'user.dart';

class RefreshCredential {
  const RefreshCredential({required this.token, required this.expiresAt});

  final String token;
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) {
    return other is RefreshCredential &&
        other.token == token &&
        other.expiresAt == expiresAt;
  }

  @override
  int get hashCode => Object.hash(token, expiresAt);

  @override
  String toString() => 'RefreshCredential(expires $expiresAt)';
}

class AuthTokens {
  const AuthTokens({
    required this.access,
    required this.accessExpiresAt,
    required this.refresh,
    required this.refreshExpiresAt,
  });

  final String access;
  final DateTime accessExpiresAt;
  final String refresh;
  final DateTime refreshExpiresAt;

  RefreshCredential get refreshCredential =>
      RefreshCredential(token: refresh, expiresAt: refreshExpiresAt);

  bool accessNeedsRefresh(DateTime now, Duration leeway) =>
      accessExpiresAt.difference(now) < leeway;

  @override
  bool operator ==(Object other) {
    return other is AuthTokens &&
        other.access == access &&
        other.accessExpiresAt == accessExpiresAt &&
        other.refresh == refresh &&
        other.refreshExpiresAt == refreshExpiresAt;
  }

  @override
  int get hashCode =>
      Object.hash(access, accessExpiresAt, refresh, refreshExpiresAt);

  @override
  String toString() => 'AuthTokens(access expires $accessExpiresAt)';
}

class AuthGrant {
  const AuthGrant({required this.tokens, required this.user});

  final AuthTokens tokens;
  final User user;

  @override
  bool operator ==(Object other) {
    return other is AuthGrant && other.tokens == tokens && other.user == user;
  }

  @override
  int get hashCode => Object.hash(tokens, user);
}
