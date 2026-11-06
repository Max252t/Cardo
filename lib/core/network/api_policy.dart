abstract final class ApiPolicy {
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration sendTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration proactiveRefreshLeeway = Duration(seconds: 60);
  static const String authorizationHeader = 'Authorization';
}

abstract final class ApiPaths {
  static const String register = '/api/auth/register';
  static const String login = '/api/auth/login';
  static const String refresh = '/api/auth/refresh';
  static const String logout = '/api/auth/logout';
  static const String me = '/api/me';
  static const String boards = '/api/boards';
  static const String healthz = '/healthz';
  static const String readyz = '/readyz';

  static const String afterSeqParam = 'after_seq';

  static String board(String id) => '/api/boards/${Uri.encodeComponent(id)}';

  static String boardEvents(String id) => '${board(id)}/events';

  static const Set<String> public = <String>{
    register,
    login,
    refresh,
    healthz,
    readyz,
  };
}
