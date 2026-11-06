import 'dart:async';

import 'package:cardo/core/realtime/scheduler.dart';
import 'package:cardo/features/board/data/fake/fake_board_server.dart';
import 'package:cardo/features/board/data/realtime/board_catch_up.dart';
import 'package:cardo/features/board/data/realtime/board_sync_engine.dart';
import 'package:cardo/features/board/data/realtime/protocol_issue.dart';
import 'package:cardo/features/board/data/realtime/realtime_credentials.dart';
import 'package:cardo/features/board/data/realtime/realtime_transport.dart';
import 'package:cardo/features/board/data/sync_signal.dart';
import 'package:cardo/features/board/domain/board_model.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixed_random.dart';
import 'board_fixtures.dart';
import 'manual_transport.dart';

class RecordingScheduler implements Scheduler {
  final List<Duration> afterDelays = <Duration>[];
  final List<Duration> everyPeriods = <Duration>[];

  @override
  Timer after(Duration delay, void Function() callback) {
    afterDelays.add(delay);
    return Timer(delay, callback);
  }

  @override
  Timer every(Duration period, void Function() callback) {
    everyPeriods.add(period);
    return Timer.periodic(period, (_) => callback());
  }
}

class ScriptedCredentials implements RealtimeCredentials {
  ScriptedCredentials(this.now, {this.ttl = const Duration(hours: 1)});

  final DateTime Function() now;
  Duration ttl;
  int issued = 0;
  int renews = 0;
  int currents = 0;
  int unavailable = 0;
  bool ended = false;
  final List<String?> staleSeen = <String?>[];

  AccessGrant _grant() =>
      AccessGrant(token: 'tok-$issued', expiresAt: now().add(ttl));

  @override
  Future<AccessGrant?> current() async {
    currents++;
    return ended ? null : _grant();
  }

  @override
  Future<CredentialRenewal> renew({String? staleAccess}) async {
    renews++;
    staleSeen.add(staleAccess);
    if (ended) {
      return const CredentialsSessionEnded();
    }
    if (unavailable > 0) {
      unavailable--;
      return const CredentialsUnavailable();
    }
    issued++;
    return CredentialsRenewed(_grant());
  }
}

const CurrentUser rigUser = CurrentUser(
  userId: 'u1',
  name: 'One',
  email: 'one@example.test',
  avatarColor: '#2D68F5',
);

BoardSyncEngine buildEngine({
  required RealtimeTransport transport,
  required RealtimeCredentials credentials,
  required BoardCatchUpSource catchUp,
  required int initialSeq,
  required Scheduler scheduler,
  required DateTime Function() now,
  required FixedRandom random,
  String boardId = 'board',
}) {
  return BoardSyncEngine(
    boardId: boardId,
    currentUser: rigUser,
    wsBaseUri: Uri(scheme: 'ws', host: 'x.test', path: '/pre'),
    transport: transport,
    credentials: credentials,
    catchUp: catchUp,
    initialSeq: initialSeq,
    scheduler: scheduler,
    now: now,
    random: random,
  );
}

class EngineRig {
  EngineRig(
    this.tester, {
    BoardModel? board,
    Duration ttl = const Duration(hours: 1),
    double jitter = 0.5,
    Duration latency = Duration.zero,
    int pageSize = 1000,
    int? initialSeq,
  }) : random = FixedRandom(jitter),
       scheduler = RecordingScheduler() {
    now = tester.binding.clock.now;
    final initial = board ?? makeBoard();
    server = FakeBoardServer(
      initial: initial,
      currentUserId: rigUser.userId,
      latency: latency,
      scheduler: scheduler,
      now: now,
      pageSize: pageSize,
    );
    creds = ScriptedCredentials(now, ttl: ttl);
    engine = buildEngine(
      transport: server,
      credentials: creds,
      catchUp: server,
      initialSeq: initialSeq ?? initial.seq,
      scheduler: scheduler,
      now: now,
      random: random,
    );
    engine.signals.listen(signals.add);
    engine.issues.listen(issues.add);
  }

  final WidgetTester tester;
  final FixedRandom random;
  final RecordingScheduler scheduler;
  late final DateTime Function() now;
  late final FakeBoardServer server;
  late final ScriptedCredentials creds;
  late final BoardSyncEngine engine;
  final List<SyncSignal> signals = <SyncSignal>[];
  final List<ProtocolIssue> issues = <ProtocolIssue>[];

  Future<void> run(int ms) => tester.pump(Duration(milliseconds: ms));

  Future<void> start([int settleMs = 10]) async {
    engine.start();
    await run(settleMs);
  }

  List<T> of<T extends SyncSignal>() => signals.whereType<T>().toList();

  List<(String, int?)> get connectionTrail => <(String, int?)>[
    for (final signal in of<ConnectionSignal>())
      (signal.status.name, signal.reconnectSeconds),
  ];

  List<int> get eventSeqs => <int>[
    for (final signal in of<EventsSignal>())
      for (final event in signal.events) event.seq,
  ];

  int get readyCount => of<ReadySignal>().length;

  void clearSignals() => signals.clear();

  Future<void> dispose() => engine.dispose();
}

typedef RigBody = Future<void> Function(EngineRig rig);

void rigTest(
  String description,
  RigBody body, {
  BoardModel? board,
  Duration ttl = const Duration(hours: 1),
  double jitter = 0.5,
  Duration latency = Duration.zero,
  int pageSize = 1000,
}) {
  testWidgets(description, (tester) async {
    final rig = EngineRig(
      tester,
      board: board,
      ttl: ttl,
      jitter: jitter,
      latency: latency,
      pageSize: pageSize,
    );
    await body(rig);
    await rig.dispose();
  });
}

MoveCard moveA1(String opId, {String to = colB, int baseVersion = 1}) {
  return MoveCard(
    opId: opId,
    cardId: 'a1',
    toColumnId: to,
    baseVersion: baseVersion,
  );
}

class ManualEngine {
  ManualEngine(EngineRig rig, {int initialSeq = 10}) {
    engine = buildEngine(
      transport: transport,
      credentials: rig.creds,
      catchUp: catchUp,
      initialSeq: initialSeq,
      scheduler: rig.scheduler,
      now: rig.now,
      random: rig.random,
    );
    engine.signals.listen(signals.add);
    engine.issues.listen(issues.add);
  }

  final ManualTransport transport = ManualTransport();
  final StubCatchUp catchUp = StubCatchUp();
  final List<SyncSignal> signals = <SyncSignal>[];
  final List<ProtocolIssue> issues = <ProtocolIssue>[];
  late final BoardSyncEngine engine;

  ManualChannel get channel => transport.last;

  List<T> of<T extends SyncSignal>() => signals.whereType<T>().toList();

  List<(String, int?)> get trail => <(String, int?)>[
    for (final signal in of<ConnectionSignal>())
      (signal.status.name, signal.reconnectSeconds),
  ];
}
