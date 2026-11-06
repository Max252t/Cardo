abstract final class AppRoutes {
  static const String splash = '/splash';
  static const String config = '/config';
  static const String login = '/login';
  static const String register = '/register';
  static const String boards = '/boards';
  static const String profile = '/profile';
  static const String invite = '/invite';
  static const String demo = '/demo';
  static const String design = '/dev/design';
  static const String fromParam = 'from';

  static String board(String id) => '$boards/${Uri.encodeComponent(id)}';

  static String inviteFor(String token) =>
      '$invite/${Uri.encodeComponent(token)}';

  static bool isInvitePath(String path) => path.startsWith('$invite/');

  static String splashFrom(String location) => withFrom(splash, location);

  static String withFrom(String route, String? from) {
    if (from == null) {
      return route;
    }
    return Uri(
      path: route,
      queryParameters: <String, String>{fromParam: from},
    ).toString();
  }

  static String keepFrom(String route, Uri current) =>
      withFrom(route, current.queryParameters[fromParam]);
}
