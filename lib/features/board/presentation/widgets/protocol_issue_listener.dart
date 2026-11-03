import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/realtime/protocol_issue.dart';
import '../board_providers.dart';
import '../protocol_issue_tally.dart';
import 'board_snackbar.dart';

class ProtocolIssueListener extends ConsumerStatefulWidget {
  const ProtocolIssueListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ProtocolIssueListener> createState() =>
      _ProtocolIssueListenerState();
}

class _ProtocolIssueListenerState extends ConsumerState<ProtocolIssueListener> {
  final ProtocolIssueTally _tally = ProtocolIssueTally();
  StreamSubscription<ProtocolIssue>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ref.read(boardGatewayProvider).issues.listen(_onIssue);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _onIssue(ProtocolIssue issue) {
    if (!mounted || !_tally.record(issue)) {
      return;
    }
    showBoardSnackbar(
      context,
      message: AppLocalizations.of(context).protocolUpdateApp,
      icon: LucideIcons.info,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
