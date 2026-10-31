import '../../../core/network/json_fields.dart';
import '../domain/auth_tokens.dart';
import '../domain/user.dart';

User userFromJson(Object? raw) {
  final json = asJsonMap(raw, 'user');
  return User(
    id: readNonEmptyString(json, 'id'),
    email: readString(json, 'email'),
    displayName: readString(json, 'display_name'),
    avatarColor: normalizeAvatarColor(readString(json, 'avatar_color')),
    createdAt: readDate(json, 'created_at'),
  );
}

AuthTokens tokensFromJson(Object? raw, {required DateTime now}) {
  final json = asJsonMap(raw, 'token response');
  final lifetime = readInt(json, 'expires_in');
  if (lifetime < 0) {
    throw const FormatException('Negative expires_in');
  }
  return AuthTokens(
    access: readNonEmptyString(json, 'access_token'),
    accessExpiresAt: now.toUtc().add(Duration(seconds: lifetime)),
    refresh: readNonEmptyString(json, 'refresh_token'),
    refreshExpiresAt: readDate(json, 'refresh_expires_at'),
  );
}

AuthGrant grantFromJson(Object? raw, {required DateTime now}) {
  final json = asJsonMap(raw, 'token response');
  return AuthGrant(
    tokens: tokensFromJson(json, now: now),
    user: userFromJson(json['user']),
  );
}
