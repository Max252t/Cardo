import 'user.dart';

enum SignOutReason { expired, reused }

sealed class Session {
  const Session();
}

final class SessionRestoring extends Session {
  const SessionRestoring();

  @override
  bool operator ==(Object other) => other is SessionRestoring;

  @override
  int get hashCode => (SessionRestoring).hashCode;
}

final class SessionUnavailable extends Session {
  const SessionUnavailable();

  @override
  bool operator ==(Object other) => other is SessionUnavailable;

  @override
  int get hashCode => (SessionUnavailable).hashCode;
}

final class SessionSignedOut extends Session {
  const SessionSignedOut({this.reason});

  final SignOutReason? reason;

  @override
  bool operator ==(Object other) =>
      other is SessionSignedOut && other.reason == reason;

  @override
  int get hashCode => Object.hash(SessionSignedOut, reason);
}

final class SessionSignedIn extends Session {
  const SessionSignedIn(this.user);

  final User user;

  @override
  bool operator ==(Object other) =>
      other is SessionSignedIn && other.user == user;

  @override
  int get hashCode => Object.hash(SessionSignedIn, user);
}
