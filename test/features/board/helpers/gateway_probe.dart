import 'dart:async';

import 'package:cardo/features/board/data/board_gateway.dart';
import 'package:cardo/features/board/data/sync_signal.dart';
import 'package:cardo/features/board/domain/board_event.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:flutter_test/flutter_test.dart';

class GatewayProbe {
  GatewayProbe(this.gateway, {bool autoConnect = true}) {
    _subscription = gateway.signals.listen(signals.add);
    if (autoConnect) {
      gateway.connect();
    }
  }

  final BoardGateway gateway;
  final List<SyncSignal> signals = <SyncSignal>[];
  late final StreamSubscription<SyncSignal> _subscription;

  Future<void> settle() => pumpEventQueue();

  List<BoardEvent> get events => <BoardEvent>[
    for (final signal in signals.whereType<EventsSignal>()) ...signal.events,
  ];

  List<NackSignal> get nacks => signals.whereType<NackSignal>().toList();

  List<String> get duplicates => <String>[
    for (final signal in signals.whereType<DuplicatesSignal>()) ...signal.opIds,
  ];

  Future<SendOutcome> send(BoardOp op) async {
    final outcome = gateway.send(op);
    await settle();
    return outcome;
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await gateway.dispose();
  }
}
