import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../theme/cardo_durations.dart';
import '../data/demo_board_fixture.dart';
import '../data/fake_board_gateway.dart';
import 'board_providers.dart';
import 'board_scope.dart';
import 'board_screen.dart';

class DemoBoardPage extends ConsumerStatefulWidget {
  const DemoBoardPage({super.key});

  @override
  ConsumerState<DemoBoardPage> createState() => _DemoBoardPageState();
}

class _DemoBoardPageState extends ConsumerState<DemoBoardPage> {
  late final FakeBoardGateway _gateway;

  @override
  void initState() {
    super.initState();
    _gateway = FakeBoardGateway(
      initial: demoBoardSnapshot(now: ref.read(nowProvider)()),
      confirmDelay: CardoDurations.syncConfirmDelay,
    );
  }

  @override
  void dispose() {
    unawaited(_gateway.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    return BoardScope(
      gateway: _gateway,
      navigation: BoardNavigation(onBack: () => router.go(AppRoutes.config)),
      child: const BoardScreen(),
    );
  }
}
