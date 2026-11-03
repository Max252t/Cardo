import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/realtime/connection_status.dart';
import '../board_providers.dart';

class BoardResumeListener extends ConsumerStatefulWidget {
  const BoardResumeListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BoardResumeListener> createState() =>
      _BoardResumeListenerState();
}

class _BoardResumeListenerState extends ConsumerState<BoardResumeListener> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _onResume() {
    if (!mounted) {
      return;
    }
    final state = ref.read(boardNotifierProvider);
    if (state.ended == null && state.connection != ConnectionStatus.connected) {
      ref.read(boardNotifierProvider.notifier).retryConnection();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
