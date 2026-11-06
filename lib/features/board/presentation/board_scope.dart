import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/board_gateway.dart';
import '../domain/board_session.dart';
import 'board_providers.dart';

class BoardScope extends StatefulWidget {
  const BoardScope({
    super.key,
    required this.gateway,
    required this.navigation,
    required this.child,
    this.liveUser,
  });

  final BoardGateway gateway;
  final BoardNavigation navigation;
  final Provider<CurrentUser?>? liveUser;
  final Widget child;

  @override
  State<BoardScope> createState() => _BoardScopeState();
}

class _BoardScopeState extends State<BoardScope> {
  late final ProviderContainer _container;

  @override
  void initState() {
    super.initState();
    final liveUser = widget.liveUser;
    _container = ProviderContainer(
      parent: ProviderScope.containerOf(context, listen: false),
      overrides: [
        boardGatewayProvider.overrideWithValue(widget.gateway),
        boardNavigationProvider.overrideWithValue(widget.navigation),
        if (liveUser != null)
          liveUserProvider.overrideWith((ref) => ref.watch(liveUser)),
      ],
    );
  }

  @override
  void dispose() {
    _container.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UncontrolledProviderScope(
      container: _container,
      child: widget.child,
    );
  }
}
