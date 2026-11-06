import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/domain/session.dart';
import '../features/auth/presentation/auth_providers.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/profile_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/board/presentation/board_route_page.dart';
import '../features/board/presentation/demo_board_page.dart';
import '../features/board_settings/presentation/self_exit.dart';
import '../features/boards/presentation/boards_screen.dart';
import '../features/design_preview/design_system_preview.dart';
import '../features/invites/presentation/invite_screen.dart';
import '../shared/providers/app_config_provider.dart';
import 'app_routes.dart';
import 'config_screen.dart';

String? resolveRedirect({
  required bool configValid,
  required Session? session,
  required Uri location,
  required bool debug,
}) {
  final path = location.path;
  if (path == AppRoutes.demo || path == AppRoutes.design) {
    return debug ? null : AppRoutes.boards;
  }
  if (!configValid) {
    return path == AppRoutes.config ? null : AppRoutes.config;
  }
  if (path == AppRoutes.config) {
    return AppRoutes.boards;
  }
  final current = session ?? const SessionRestoring();
  switch (current) {
    case SessionRestoring():
    case SessionUnavailable():
      return path == AppRoutes.splash
          ? null
          : AppRoutes.splashFrom(location.toString());
    case SessionSignedOut():
      final open = path == AppRoutes.login || path == AppRoutes.register;
      if (open) {
        return null;
      }
      final origin = path == AppRoutes.splash
          ? location.queryParameters[AppRoutes.fromParam]
          : location.toString();
      final target = _safeTarget(origin);
      final invite =
          target != null && AppRoutes.isInvitePath(Uri.parse(target).path);
      return AppRoutes.withFrom(AppRoutes.login, invite ? target : null);
    case SessionSignedIn():
      if (path == AppRoutes.splash) {
        final target = location.queryParameters[AppRoutes.fromParam];
        return _safeTarget(target) ?? AppRoutes.boards;
      }
      if (path == AppRoutes.login || path == AppRoutes.register) {
        final target = location.queryParameters[AppRoutes.fromParam];
        return _safeTarget(target) ?? AppRoutes.boards;
      }
      return path == '/' ? AppRoutes.boards : null;
  }
}

String? _safeTarget(String? target) {
  if (target == null ||
      !target.startsWith('/') ||
      target.startsWith('//') ||
      target.contains(r'\')) {
    return null;
  }
  final uri = Uri.tryParse(target);
  if (uri == null || uri.hasScheme || uri.hasAuthority) {
    return null;
  }
  final path = uri.path;
  if (path == AppRoutes.splash ||
      path == AppRoutes.login ||
      path == AppRoutes.register ||
      path == AppRoutes.config) {
    return null;
  }
  return target;
}

class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen<Session>(sessionProvider, (_, next) {
    if (next is! SessionSignedIn) {
      ref.read(selfExitProvider.notifier).reset();
    }
    refresh.notify();
  });
  final config = ref.watch(appConfigProvider);
  final router = GoRouter(
    initialLocation: AppRoutes.boards,
    refreshListenable: refresh,
    redirect: (context, state) => resolveRedirect(
      configValid: config.isValid,
      session: config.isValid ? ref.read(sessionProvider) : null,
      location: state.uri,
      debug: kDebugMode,
    ),
    routes: <RouteBase>[
      GoRoute(path: '/', redirect: (context, state) => AppRoutes.boards),
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.config,
        builder: (context, state) => const ConfigScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.boards,
        builder: (context, state) => const BoardsScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: ':id',
            builder: (context, state) =>
                BoardRoutePage(boardId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '${AppRoutes.invite}/:token',
        builder: (context, state) =>
            InviteScreen(rawToken: state.pathParameters['token']),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.demo,
        builder: (context, state) => const DemoBoardPage(),
      ),
      GoRoute(
        path: AppRoutes.design,
        builder: (context, state) => const DesignSystemPreview(),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
