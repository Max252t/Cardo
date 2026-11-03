import '../../../auth/data/token_manager.dart';

class AccessGrant {
  const AccessGrant({required this.token, required this.expiresAt});

  final String token;
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) {
    return other is AccessGrant &&
        other.token == token &&
        other.expiresAt == expiresAt;
  }

  @override
  int get hashCode => Object.hash(token, expiresAt);

  @override
  String toString() => 'AccessGrant(expires $expiresAt)';
}

sealed class CredentialRenewal {
  const CredentialRenewal();
}

final class CredentialsRenewed extends CredentialRenewal {
  const CredentialsRenewed(this.grant);

  final AccessGrant grant;
}

final class CredentialsSessionEnded extends CredentialRenewal {
  const CredentialsSessionEnded();
}

final class CredentialsUnavailable extends CredentialRenewal {
  const CredentialsUnavailable();
}

abstract interface class RealtimeCredentials {
  Future<AccessGrant?> current();

  Future<CredentialRenewal> renew({String? staleAccess});
}

class TokenManagerCredentials implements RealtimeCredentials {
  const TokenManagerCredentials(this._manager);

  final TokenManager _manager;

  @override
  Future<AccessGrant?> current() async {
    final token = await _manager.accessToken();
    final expiresAt = _manager.currentAccessExpiresAt;
    if (token == null || expiresAt == null) {
      return null;
    }
    return AccessGrant(token: token, expiresAt: expiresAt);
  }

  @override
  Future<CredentialRenewal> renew({String? staleAccess}) async {
    final outcome = await _manager.refresh(staleAccess: staleAccess);
    return switch (outcome) {
      Refreshed(:final tokens) => CredentialsRenewed(
        AccessGrant(token: tokens.access, expiresAt: tokens.accessExpiresAt),
      ),
      SessionEnded() || NoCredential() => const CredentialsSessionEnded(),
      RefreshFailed() => const CredentialsUnavailable(),
    };
  }
}

class StaticCredentials implements RealtimeCredentials {
  StaticCredentials({this.token = 'static-token', DateTime? expiresAt})
    : expiresAt = expiresAt ?? DateTime.utc(2100);

  final String token;
  final DateTime expiresAt;

  @override
  Future<AccessGrant?> current() async =>
      AccessGrant(token: token, expiresAt: expiresAt);

  @override
  Future<CredentialRenewal> renew({String? staleAccess}) async =>
      CredentialsRenewed(AccessGrant(token: token, expiresAt: expiresAt));
}
