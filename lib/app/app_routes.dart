abstract final class AppRoutes {
  static const String splash = '/splash';
  static const String config = '/config';
  static const String login = '/login';
  static const String register = '/register';
  static const String boards = '/boards';
  static const String profile = '/profile';
  static const String demo = '/demo';
  static const String design = '/dev/design';
  static const String fromParam = 'from';

  static String board(String id) => '$boards/${Uri.encodeComponent(id)}';

  static String splashFrom(String location) => Uri(
    path: splash,
    queryParameters: <String, String>{fromParam: location},
  ).toString();
}
