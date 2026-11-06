import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../theme/cardo_durations.dart';
import '../boards_providers.dart';

class BoardsAutoRefresh extends ConsumerStatefulWidget {
  const BoardsAutoRefresh({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BoardsAutoRefresh> createState() => _BoardsAutoRefreshState();
}

class _BoardsAutoRefreshState extends ConsumerState<BoardsAutoRefresh> {
  late final AppLifecycleListener _lifecycle;
  Timer? _timer;
  late bool _foreground;
  bool _current = true;
  bool _bound = false;
  bool _leftForBoard = false;

  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    _lifecycle = AppLifecycleListener(
      onResume: _onResume,
      onHide: _onBackground,
      onPause: _onBackground,
      onDetach: _onBackground,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.of(context)?.isCurrent ?? true;
    final onList =
        GoRouter.of(context).routerDelegate.currentConfiguration.uri.path ==
        AppRoutes.boards;
    if (!current && !onList) {
      _leftForBoard = true;
    }
    final regained = _bound && current && !_current && _leftForBoard;
    if (current) {
      _leftForBoard = false;
    }
    _current = current;
    _bound = true;
    _sync();
    if (regained) {
      _refresh();
    }
  }

  @override
  void dispose() {
    _stop();
    _lifecycle.dispose();
    super.dispose();
  }

  void _sync() {
    if (_foreground && _current) {
      _timer ??= Timer.periodic(
        CardoDurations.boardsRefresh,
        (_) => _refresh(),
      );
    } else {
      _stop();
    }
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _onBackground() {
    _foreground = false;
    _sync();
  }

  void _onResume() {
    if (!mounted) {
      return;
    }
    _foreground = true;
    _stop();
    _sync();
    if (_current) {
      _refresh();
    }
  }

  void _refresh() {
    if (!mounted) {
      return;
    }
    unawaited(ref.read(boardsListProvider.notifier).refreshSilently());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
