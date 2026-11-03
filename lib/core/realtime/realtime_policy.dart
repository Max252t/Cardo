abstract final class RealtimePolicy {
  static const Duration gapWait = Duration(seconds: 1);
  static const Duration readyTimeout = Duration(seconds: 30);
  static const Duration refreshAckTimeout = Duration(seconds: 15);
  static const Duration refreshRetry = Duration(seconds: 5);
  static const Duration catchUpRetry = Duration(seconds: 1);
  static const Duration tokenRefreshLeeway = Duration(seconds: 60);
  static const Duration backoffBase = Duration(milliseconds: 500);
  static const Duration backoffMax = Duration(seconds: 30);
  static const Duration abuseBackoff = Duration(seconds: 30);
  static const Duration pendingMaxAge = Duration(hours: 24);
  static const Duration countdownTick = Duration(seconds: 1);
  static const Duration opRefillInterval = Duration(milliseconds: 67);
  static const Duration rateLimitPause = Duration(seconds: 1);
  static const Duration pingInterval = Duration(seconds: 20);
  static const Duration idlePoll = Duration(seconds: 5);
  static const Duration minRefreshDelay = Duration(seconds: 5);
  static const Duration serverRefill = Duration(milliseconds: 50);
  static const Duration serverStrikeWindow = Duration(seconds: 10);
  static const double backoffJitter = 0.2;
  static const int maxBackoffExponent = 16;
  static const int maxMessageBytes = 64 * 1024;
  static const int catchUpGiveUpAfter = 2;
  static const int authLoopLimit = 3;
  static const int opBurst = 10;
  static const int serverOpBurst = 20;
  static const int serverStrikeLimit = 100;
  static const int rateLimitRetries = 30;
  static const int upgradeUnauthorized = 401;
  static const int upgradeForbidden = 403;
  static const int upgradeNotFound = 404;
  static const int protocolVersion = 1;
  static const String clientName = 'flutter/0.1.0';
  static const List<String> wsPathSegments = <String>['ws', 'boards'];
}

abstract final class CloseCodes {
  static const int normal = 1000;
  static const int goingAway = 1001;
  static const int tooBig = 1009;
  static const int syncFailure = 1011;
  static const int tryAgainLater = 1013;
  static const int tokenExpired = 4001;
  static const int accessRevoked = 4003;
  static const int boardDeleted = 4004;
  static const int rateAbuse = 4008;
  static const int slowClient = 4009;
  static const int protocolViolation = 4400;
}
