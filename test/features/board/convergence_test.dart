import 'dart:math' as math;

import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/core/network/api_failure.dart';
import 'package:cardo/core/ranking/rank.dart';
import 'package:cardo/core/realtime/connection_status.dart';
import 'package:cardo/core/result/result.dart';
import 'package:cardo/features/board/data/fake/fake_board_server.dart';
import 'package:cardo/features/board/data/realtime/board_catch_up.dart';
import 'package:cardo/features/board/data/realtime/board_sync_engine.dart';
import 'package:cardo/features/board/data/realtime/realtime_transport.dart';
import 'package:cardo/features/board/data/server_board_gateway.dart';
import 'package:cardo/features/board/data/sync_signal.dart';
import 'package:cardo/features/board/domain/board_event.dart';
import 'package:cardo/features/board/domain/board_model.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_session.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/presentation/board_notifier.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/features/boards/domain/board_info.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/board_fixtures.dart';
import 'helpers/engine_rig.dart';
import 'helpers/reference_board.dart';

const String remoteUser = 'u2';

class LaggyBackend implements RealtimeTransport, BoardCatchUpSource {
  LaggyBackend(this.inner, this.random);

  final FakeBoardServer inner;
  final math.Random random;
  int maxRestMs = 900;
  int maxConnectMs = 250;
  int staleEventPages = 0;
  int staleSnapshots = 0;

  Future<void> _lag(int maxMs) {
    if (maxMs <= 0) {
      return Future<void>.value();
    }
    return Future<void>.delayed(Duration(milliseconds: random.nextInt(maxMs)));
  }

  @override
  Future<RealtimeChannel> connect(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    await _lag(maxConnectMs);
    return inner.connect(uri, headers: headers);
  }

  @override
  Future<Result<EventsPage, ApiFailure>> getEvents(
    String boardId,
    int afterSeq,
  ) async {
    final result = await inner.getEvents(boardId, afterSeq);
    await _lag(maxRestMs);
    if (result is Success<EventsPage, ApiFailure> &&
        result.value.seq < inner.seq) {
      staleEventPages++;
    }
    return result;
  }

  @override
  Future<Result<ServerBoard, ApiFailure>> getBoard(String boardId) async {
    final result = await inner.getBoard(boardId);
    await _lag(maxRestMs);
    if (result is Success<ServerBoard, ApiFailure> &&
        result.value.model.seq < inner.seq) {
      staleSnapshots++;
    }
    return result;
  }
}

class OpRecord {
  OpRecord(
    this.op,
    this.client,
    this.order,
    this.forcedReason,
    this.forcedLeft,
  );

  final BoardOp op;
  final SimClient client;
  final int order;
  final NackReason? forcedReason;
  int forcedLeft;
  final List<NackReason> forcedUsed = <NackReason>[];
  bool judged = false;
  NackReason? expected;
  int judgeOrder = -1;

  String get opId => op.opId;

  List<NackReason> get nacks => client.nackLog[opId] ?? const <NackReason>[];

  NackReason? get surfaced => client.surfaced[opId];

  bool get hadTransient => forcedUsed.isNotEmpty || nacks.any(isTransientNack);

  @override
  String toString() => '$op';
}

bool isTransientNack(NackReason reason) =>
    reason == NackReason.rateLimited || reason == NackReason.internal;

class SimClient {
  SimClient({
    required this.index,
    required this.server,
    required this.backend,
    required this.scheduler,
    required this.now,
    required int seed,
  }) {
    final board = server.board;
    creds = ScriptedCredentials(now);
    engine = BoardSyncEngine(
      boardId: board.id,
      currentUser: rigUser,
      wsBaseUri: Uri(scheme: 'ws', host: 'sim.test'),
      transport: backend,
      credentials: creds,
      catchUp: backend,
      initialSeq: board.seq,
      scheduler: scheduler,
      now: now,
      random: math.Random(seed),
    );
    final snapshot = BoardSnapshot(
      board: board,
      currentUser: rigUser,
      boards: const <BoardSummary>[],
      presence: BoardPresence(onlineUserIds: const <String>[]),
      connection: ConnectionStatus.syncing,
    );
    gateway = ServerBoardGateway(snapshot, engine);
    var counter = 0;
    container = ProviderContainer(
      overrides: [
        boardGatewayProvider.overrideWithValue(gateway),
        idGeneratorProvider.overrideWithValue(() => 'c$index-${counter++}'),
        nowProvider.overrideWithValue(now),
        boardSyncConfigProvider.overrideWithValue(
          const BoardSyncConfig(
            nackHold: Duration(milliseconds: 200),
            retryDelay: Duration(milliseconds: 100),
            maxInternalRetries: 2,
          ),
        ),
      ],
    );
    container.listen(boardNotifierProvider, (_, next) {
      for (final item in next.pending) {
        final rejection = item.rejection;
        if (item.isRejected && rejection != null) {
          surfaced[item.opId] = rejection.reason;
        }
      }
    });
    gateway.signals.listen((signal) {
      switch (signal) {
        case NackSignal(:final opId, :final rejection):
          nacks[rejection.reason] = (nacks[rejection.reason] ?? 0) + 1;
          nackLog.putIfAbsent(opId, () => <NackReason>[]).add(rejection.reason);
        case SnapshotSignal():
          snapshots++;
        case ResyncedSignal():
          resyncs++;
        default:
          break;
      }
    });
  }

  final int index;
  final FakeBoardServer server;
  final LaggyBackend backend;
  final RecordingScheduler scheduler;
  final DateTime Function() now;
  late final ScriptedCredentials creds;
  late final BoardSyncEngine engine;
  late final ServerBoardGateway gateway;
  late final ProviderContainer container;
  final Map<NackReason, int> nacks = <NackReason, int>{};
  final Map<String, List<NackReason>> nackLog = <String, List<NackReason>>{};
  final Map<String, NackReason> surfaced = <String, NackReason>{};
  final Set<String> known = <String>{};
  int snapshots = 0;
  int resyncs = 0;

  BoardSyncState get state => container.read(boardNotifierProvider);

  BoardNotifier get notifier => container.read(boardNotifierProvider.notifier);

  Future<void> dispose() async {
    container.dispose();
    await gateway.dispose();
  }
}

class Projection {
  const Projection(this.title, this.columns, this.cards, this.members);

  final String title;
  final List<ColumnModel> columns;
  final List<CardModel> cards;
  final List<BoardMember> members;

  @override
  bool operator ==(Object other) =>
      other is Projection &&
      other.title == title &&
      _same(other.columns, columns) &&
      _same(other.cards, cards) &&
      _same(other.members, members);

  @override
  int get hashCode => Object.hash(title, columns.length, cards.length);

  static bool _same(List<Object> a, List<Object> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  String toString() => 'Projection($title, $columns, $cards, $members)';
}

Projection project(BoardModel board) {
  final cards = board.cards.where((card) => !card.archived).toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  final columns = List<ColumnModel>.of(board.orderedColumns);
  final members = List<BoardMember>.of(board.members)
    ..sort((a, b) => a.userId.compareTo(b.userId));
  return Projection(board.title, columns, cards, members);
}

class Sim {
  Sim(
    this.tester, {
    required this.seed,
    required this.clients,
    required this.opsPerClient,
    required this.disruptions,
    this.remoteRate = 12,
  }) : random = math.Random(seed) {
    final now = _millisClock(tester);
    scheduler = RecordingScheduler();
    server = FakeBoardServer(
      initial: makeBoard(),
      currentUserId: rigUser.userId,
      latency: const Duration(milliseconds: 20),
      scheduler: scheduler,
      now: now,
      handshakeDelay: Duration(milliseconds: 30 + random.nextInt(170)),
    );
    server.rejectWhen = _judge;
    ref = ReferenceBoard.from(server.board);
    backend = LaggyBackend(server, math.Random(seed * 13 + 5));
    this.now = now;
    for (var i = 0; i < clients; i++) {
      all.add(
        SimClient(
          index: i,
          server: server,
          backend: backend,
          scheduler: scheduler,
          now: now,
          seed: seed * 31 + i,
        ),
      );
    }
  }

  final WidgetTester tester;
  final int seed;
  final int clients;
  final int opsPerClient;
  final bool disruptions;
  final int remoteRate;
  final math.Random random;
  late final RecordingScheduler scheduler;
  late final FakeBoardServer server;
  late final LaggyBackend backend;
  late final ReferenceBoard ref;
  late final DateTime Function() now;
  final List<SimClient> all = <SimClient>[];
  final Map<String, OpRecord> ledger = <String, OpRecord>{};
  int step = 0;
  int judgeCounter = 0;
  int remoteCounter = 0;
  final Map<String, int> disruptionCounts = <String, int>{};
  final Map<String, int> remoteCounts = <String, int>{};

  static DateTime Function() _millisClock(WidgetTester tester) {
    return () => DateTime.fromMillisecondsSinceEpoch(
      tester.binding.clock.now().millisecondsSinceEpoch,
      isUtc: true,
    );
  }

  void _count(String name) =>
      disruptionCounts[name] = (disruptionCounts[name] ?? 0) + 1;

  void _remoteCount(String name) =>
      remoteCounts[name] = (remoteCounts[name] ?? 0) + 1;

  void syncReference() {
    if (server.seq == ref.seq) {
      return;
    }
    for (final event in server.log) {
      if (event.seq > ref.seq) {
        ref.apply(event);
      }
    }
  }

  OpRejection? _judge(BoardOp op) {
    syncReference();
    final record = ledger[op.opId];
    if (record == null) {
      return null;
    }
    final forced = record.forcedReason;
    if (forced != null && record.forcedLeft > 0) {
      record.forcedLeft--;
      record.forcedUsed.add(forced);
      return OpRejection(reason: forced);
    }
    if (!record.judged) {
      record.judged = true;
      record.expected = ref.verdict(op, rigUser.userId);
      record.judgeOrder = judgeCounter++;
    }
    return null;
  }

  void _register(SimClient client, BoardOp op) {
    final roll = random.nextInt(1000);
    NackReason? reason;
    var count = 0;
    if (roll < 30) {
      reason = NackReason.internal;
      count = 1 + random.nextInt(2);
    } else if (roll < 40) {
      reason = NackReason.internal;
      count = 3;
    } else if (roll < 60) {
      reason = NackReason.rateLimited;
      count = 1 + random.nextInt(2);
    }
    ledger[op.opId] = OpRecord(op, client, ledger.length, reason, count);
  }

  void _clientOp(SimClient client) {
    _randomOp(client);
    for (final item in client.state.pending) {
      if (client.known.add(item.opId)) {
        _register(client, item.op);
      }
    }
  }

  void _randomOp(SimClient client) {
    final view = client.state.liveView;
    final cards = view.cards.where((card) => !card.archived).toList();
    final columns = view.orderedColumns;
    if (columns.isEmpty) {
      return;
    }
    final column = columns[random.nextInt(columns.length)];
    final roll = random.nextInt(100);
    final notifier = client.notifier;
    if (cards.isEmpty || roll < 20) {
      notifier.createCard(columnId: column.id, title: 'T$step');
      return;
    }
    final card = cards[random.nextInt(cards.length)];
    if (roll < 65) {
      final count = view.cardsIn(column.id).length;
      notifier.moveCardToIndex(
        cardId: card.id,
        toColumnId: column.id,
        index: random.nextInt(count + 1),
      );
    } else if (roll < 80) {
      notifier.editCardTitle(cardId: card.id, title: 'E$step');
    } else if (roll < 90) {
      notifier.editCardDescription(
        cardId: card.id,
        description: 'D$step',
        baseDescriptionVersion: card.descriptionVersion,
      );
    } else if (cards.length > 8) {
      notifier.archiveCard(card.id);
    }
  }

  void _remote() {
    syncReference();
    final roll = random.nextInt(100);
    if (roll < 35) {
      _remoteColumn();
    } else if (roll < 55) {
      _remoteRebalance();
    } else if (roll < 75) {
      _remoteMember();
    } else {
      _remoteCard();
    }
  }

  String _remoteOpId() => 'r${remoteCounter++}';

  void _remoteCommit(BoardOp op, String name) {
    final event = server.commitRemote(op, actorId: remoteUser);
    if (event != null) {
      _remoteCount(name);
    }
  }

  void _remoteColumn() {
    final columns = ref.orderedColumns;
    final pick = columns[random.nextInt(columns.length)];
    final kind = random.nextInt(10);
    final opId = _remoteOpId();
    if (kind < 3) {
      _remoteCommit(
        CreateColumn(
          opId: opId,
          columnId: 'rc$opId',
          title: 'RC$opId',
          afterId: pick.id,
        ),
        'column.create',
      );
    } else if (kind < 6) {
      _remoteCommit(
        RenameColumn(opId: opId, columnId: pick.id, title: 'R$opId'),
        'column.rename',
      );
    } else if (kind < 9) {
      final others = columns.where((column) => column.id != pick.id).toList();
      _remoteCommit(
        MoveColumn(
          opId: opId,
          columnId: pick.id,
          baseVersion: pick.version,
          afterId: others.isEmpty
              ? null
              : others[random.nextInt(others.length)].id,
        ),
        'column.move',
      );
    } else if (columns.length > 3) {
      _remoteCommit(
        ArchiveColumn(opId: opId, columnId: pick.id),
        'column.archive',
      );
    }
  }

  void _remoteRebalance() {
    if (random.nextInt(4) == 0) {
      final columns = ref.orderedColumns;
      final ranks = ranksSequence(columns.length);
      server.commitEvent(
        (seq, ts) => ColumnsRebalancedEvent(
          seq: seq,
          serverTs: ts,
          actorId: remoteUser,
          columns: <ColumnRankEntry>[
            for (var i = 0; i < columns.length; i++)
              (columnId: columns[i].id, rank: ranks[i]),
          ],
        ),
      );
      _remoteCount('columns.rebalanced');
      return;
    }
    final candidates = <RefColumn>[
      for (final column in ref.orderedColumns)
        if (ref.activeCardsIn(column.id).length >= 2) column,
    ];
    if (candidates.isEmpty) {
      return;
    }
    final column = candidates[random.nextInt(candidates.length)];
    final cards = ref.activeCardsIn(column.id);
    final ranks = ranksSequence(cards.length);
    server.commitEvent(
      (seq, ts) => ColumnRebalancedEvent(
        seq: seq,
        serverTs: ts,
        actorId: remoteUser,
        columnId: column.id,
        cards: <CardRankEntry>[
          for (var i = 0; i < cards.length; i++)
            (cardId: cards[i].id, rank: ranks[i]),
        ],
      ),
    );
    _remoteCount('column.rebalanced');
    if (random.nextBool()) {
      final mover = cards[random.nextInt(cards.length)];
      syncReference();
      _remoteCommit(
        MoveCard(
          opId: _remoteOpId(),
          cardId: mover.id,
          toColumnId: column.id,
          afterId: cards[random.nextInt(cards.length)].id,
          baseVersion: mover.version,
        ),
        'card.move',
      );
    }
  }

  void _remoteMember() {
    final present = ref.roles.containsKey(remoteUser);
    final kind = random.nextInt(10);
    if (!present) {
      server.commitEvent(
        (seq, ts) => MemberAddedEvent(
          seq: seq,
          serverTs: ts,
          actorId: rigUser.userId,
          userId: remoteUser,
          displayName: 'Two',
          avatarColor: '#FF0000',
          role: BoardRole.values[random.nextInt(BoardRole.values.length)],
        ),
      );
      _remoteCount('member.added');
    } else if (kind < 5) {
      server.changeRole(
        remoteUser,
        BoardRole.values[random.nextInt(BoardRole.values.length)],
      );
      _remoteCount('member.role_changed');
    } else if (kind < 8) {
      server.changeRole(
        rigUser.userId,
        random.nextBool() ? BoardRole.owner : BoardRole.editor,
      );
      _remoteCount('member.role_changed.writer');
    } else {
      server.removeMember(remoteUser);
      _remoteCount('member.removed');
    }
  }

  void _remoteCard() {
    final active = <RefCard>[
      for (final card in ref.cards.values)
        if (!card.archived) card,
    ];
    if (active.isEmpty) {
      return;
    }
    final card = active[random.nextInt(active.length)];
    final kind = random.nextInt(100);
    final opId = _remoteOpId();
    if (kind < 50) {
      final columns = ref.orderedColumns;
      final target = columns[random.nextInt(columns.length)];
      final others = ref
          .activeCardsIn(target.id)
          .where((other) => other.id != card.id)
          .toList();
      _remoteCommit(
        MoveCard(
          opId: opId,
          cardId: card.id,
          toColumnId: target.id,
          afterId: others.isEmpty || random.nextBool()
              ? null
              : others[random.nextInt(others.length)].id,
          baseVersion: card.version,
        ),
        'card.move',
      );
    } else if (kind < 75) {
      _remoteCommit(
        EditCardTitle(
          opId: opId,
          cardId: card.id,
          title: 'X$opId',
          actorId: remoteUser,
        ),
        'card.edit',
      );
    } else if (kind < 90) {
      _remoteCommit(
        EditCardDescription(
          opId: opId,
          cardId: card.id,
          description: 'XD$opId',
          baseDescriptionVersion: card.descriptionVersion,
          actorId: remoteUser,
        ),
        'card.describe',
      );
    } else if (active.length > 8) {
      _remoteCommit(ArchiveCard(opId: opId, cardId: card.id), 'card.archive');
    }
  }

  void _prune(int upTo) {
    syncReference();
    for (final event in server.log) {
      final opId = event.opId;
      if (event.seq <= upTo && opId != null && ledger.containsKey(opId)) {
        server.resyncRequiredFor(opId);
      }
    }
    server.pruneLog(upTo);
  }

  void _disrupt() {
    final roll = random.nextInt(1000);
    if (roll < 25) {
      server.dropConnections();
      _count('drop');
    } else if (roll < 60) {
      server.suppressNextBroadcasts(1 + random.nextInt(3));
      _count('suppress');
    } else if (roll < 75) {
      final upTo = server.seq - random.nextInt(40);
      if (upTo > 0) {
        _prune(upTo);
        _count('prune');
      }
    } else if (roll < 85) {
      server.closeConnections(
        const [1001, 1011, 1013, 4009][random.nextInt(4)],
      );
      _count('close');
    } else if (roll < 92) {
      server.expireTokens();
      _count('expire');
    } else if (roll < 100) {
      server.failNextConnections(1 + random.nextInt(2));
      _count('refuse');
    } else if (roll < 112) {
      server.failNextEventFetches(1 + random.nextInt(2));
      _count('rest-fail');
    } else if (roll < 130) {
      server.handshakeDelay = Duration(milliseconds: random.nextInt(400));
      _count('handshake-delay');
    }
  }

  Future<void> run() async {
    for (final client in all) {
      client.engine.start();
    }
    await tester.pump(const Duration(milliseconds: 50));
    final total = clients * opsPerClient;
    for (step = 0; step < total; step++) {
      final client = all[random.nextInt(all.length)];
      _clientOp(client);
      if (random.nextInt(100) < remoteRate) {
        _remote();
      }
      if (disruptions) {
        _disrupt();
      }
      await tester.pump(Duration(milliseconds: random.nextInt(250)));
    }
  }

  bool get _quiet {
    for (final client in all) {
      final state = client.state;
      if (state.connection != ConnectionStatus.connected ||
          state.pending.isNotEmpty ||
          state.lastSeq != server.seq) {
        return false;
      }
    }
    return true;
  }

  Future<void> settle() async {
    var quietTicks = 0;
    for (var i = 0; i < 240; i++) {
      await tester.pump(const Duration(seconds: 1));
      quietTicks = _quiet ? quietTicks + 1 : 0;
      if (quietTicks >= 6) {
        break;
      }
    }
  }

  Future<void> dispose() async {
    for (final client in all) {
      await client.dispose();
    }
    await tester.pump(const Duration(seconds: 5));
  }
}

class LedgerReport {
  int created = 0;
  int applied = 0;
  int rejected = 0;
  int abandoned = 0;
  int dependents = 0;
  int resyncAcks = 0;
  int transientRetries = 0;
  int reorderExemptions = 0;
  final Map<NackReason, int> rejectedBy = <NackReason, int>{};

  @override
  String toString() =>
      'created $created = applied $applied + rejected $rejected + '
      'abandoned $abandoned + dependents $dependents';
}

bool _abandonJustified(Sim sim, OpRecord record) {
  final op = record.op;
  final ref = sim.ref;
  if (op is CreateCard) {
    return ref.everRemovedColumns.contains(op.columnId);
  }
  final cardId = op.cardId;
  if (cardId == null) {
    return false;
  }
  if (ref.everArchivedCards.contains(cardId)) {
    return true;
  }
  if (op is MoveCard && ref.everRemovedColumns.contains(op.toColumnId)) {
    return true;
  }
  if (!ref.cards.containsKey(cardId)) {
    return true;
  }
  for (final other in sim.ledger.values) {
    if (other.client == record.client &&
        other.order < record.order &&
        other.op is ArchiveCard &&
        other.op.cardId == cardId) {
      return true;
    }
  }
  return false;
}

LedgerReport verifyLedger(Sim sim) {
  sim.syncReference();
  final ref = sim.ref;
  final report = LedgerReport();
  final problems = <String>[];
  final createOf = <String, OpRecord>{};
  for (final record in sim.ledger.values) {
    final op = record.op;
    if (op is CreateCard) {
      createOf['${record.client.index}/${op.cardId}'] = record;
    }
  }
  for (final record in sim.ledger.values) {
    report.created++;
    final id = record.opId;
    final applied = ref.appliedOps.containsKey(id);
    if (record.judged) {
      if (record.expected == null && !applied) {
        problems.add('$record judged acceptable but no event carries $id');
      }
      if (record.expected != null && applied) {
        problems.add(
          '$record expected ${record.expected} but the server applied it',
        );
      }
    }
    if (record.hadTransient) {
      report.transientRetries++;
    }
    if (applied) {
      report.applied++;
      for (final reason in record.nacks) {
        if (!isTransientNack(reason) && reason != NackReason.resyncRequired) {
          problems.add('$record was nacked $reason yet applied');
        }
      }
      if (record.nacks.contains(NackReason.resyncRequired)) {
        report.resyncAcks++;
      }
      continue;
    }
    final surfaced = record.surfaced;
    if (surfaced != null) {
      report.rejected++;
      report.rejectedBy[surfaced] = (report.rejectedBy[surfaced] ?? 0) + 1;
      if (isTransientNack(surfaced)) {
        final injected = record.forcedUsed.contains(surfaced);
        final organic =
            surfaced == NackReason.rateLimited && sim.server.rateLimitedOps > 0;
        if (!injected && !organic) {
          problems.add('$record surfaced $surfaced that nobody injected');
        }
      } else if (!record.judged || record.expected != surfaced) {
        problems.add(
          '$record surfaced $surfaced but the reference verdict is '
          '${record.judged ? record.expected : 'not judged'}',
        );
      }
      continue;
    }
    if (record.client.state.abandoned.contains(id)) {
      report.abandoned++;
      if (!_abandonJustified(sim, record)) {
        problems.add('$record was abandoned although it still applied');
      }
      continue;
    }
    final cardId = record.op.cardId;
    final create = cardId == null
        ? null
        : createOf['${record.client.index}/$cardId'];
    if (create != null &&
        create != record &&
        !ref.cards.containsKey(cardId) &&
        (create.surfaced != null ||
            record.client.state.abandoned.contains(create.opId))) {
      report.dependents++;
      continue;
    }
    problems.add(
      '$record vanished: no event, no surfaced rejection '
      '(nacks ${record.nacks}), not abandoned',
    );
  }
  final chains = <String, List<OpRecord>>{};
  for (final record in sim.ledger.values) {
    final cardId = record.op.cardId;
    if (cardId != null && record.judged) {
      chains
          .putIfAbsent('${record.client.index}/$cardId', () => <OpRecord>[])
          .add(record);
    }
  }
  for (final entry in chains.entries) {
    final chain = entry.value..sort((a, b) => a.order.compareTo(b.order));
    for (var i = 1; i < chain.length; i++) {
      final earlier = chain[i - 1];
      final later = chain[i];
      if (later.judgeOrder < earlier.judgeOrder) {
        if (earlier.hadTransient) {
          report.reorderExemptions++;
        } else {
          problems.add(
            'server saw $later before $earlier on ${entry.key} '
            '(created in the opposite order)',
          );
        }
      }
    }
  }
  expect(
    problems,
    isEmpty,
    reason: 'op ledger ($report):\n${problems.take(20).join('\n')}',
  );
  expect(
    report.applied + report.rejected + report.abandoned + report.dependents,
    report.created,
    reason: '$report',
  );
  return report;
}

void expectConverged(Sim sim) {
  sim.syncReference();
  final reference = sim.ref.signature();
  expect(
    signatureOf(sim.server.board),
    reference,
    reason: 'server table vs independent reference',
  );
  final truth = project(sim.server.board);
  for (final client in sim.all) {
    final state = client.state;
    final reason = 'client ${client.index}';
    expect(state.ended, isNull, reason: reason);
    expect(state.connection, ConnectionStatus.connected, reason: reason);
    expect(state.pending, isEmpty, reason: '$reason pending ${state.pending}');
    expect(state.lastSeq, sim.server.seq, reason: reason);
    expect(state.confirmed.seq, sim.server.seq, reason: reason);
    expect(
      signatureOf(state.confirmed),
      reference,
      reason: '$reason confirmed vs reference',
    );
    expect(
      signatureOf(state.view),
      reference,
      reason: '$reason view vs reference',
    );
    expect(project(state.view), truth, reason: reason);
    expect(project(state.confirmed), truth, reason: reason);
    for (final column in truth.columns) {
      expect(
        state.view.cardsIn(column.id).map((card) => card.id).toList(),
        sim.server.board.cardsIn(column.id).map((card) => card.id).toList(),
        reason: '$reason column ${column.id}',
      );
    }
  }
}

LedgerReport verifyRun(Sim sim) {
  expectConverged(sim);
  return verifyLedger(sim);
}

void expectScenarios(Sim sim, LedgerReport report) {
  final remote = sim.remoteCounts;
  expect(remote['member.role_changed'], greaterThan(0));
  expect(remote['column.rebalanced'], greaterThan(0));
  expect(sim.ref.columnEvents, greaterThan(0));
  expect(report.rejected, greaterThan(0));
  expect(report.applied, greaterThan(report.created ~/ 2));
}

void main() {
  testWidgets('clients converge without any disruptions', (tester) async {
    final sim = Sim(
      tester,
      seed: 7,
      clients: 3,
      opsPerClient: 150,
      disruptions: false,
    );

    await sim.run();
    await sim.settle();

    final report = verifyRun(sim);
    expect(sim.server.log.length, greaterThan(100));
    expectScenarios(sim, report);
    expect(sim.server.backlogDelivered, greaterThanOrEqualTo(0));
    await sim.dispose();
  });

  testWidgets(
    '4 clients x 250 random ops converge through drops, gaps and pruning',
    (tester) async {
      final sim = Sim(
        tester,
        seed: 20260101,
        clients: 4,
        opsPerClient: 250,
        disruptions: true,
      );

      await sim.run();
      await sim.settle();

      final report = verifyRun(sim);
      expectScenarios(sim, report);
      expect(sim.disruptionCounts['drop'], greaterThan(0));
      expect(sim.disruptionCounts['suppress'], greaterThan(0));
      expect(sim.disruptionCounts['prune'], greaterThan(0));
      expect(sim.server.eventFetches, greaterThan(0));
      expect(
        sim.server.snapshotLoads + sim.server.snapshotsSent,
        greaterThan(0),
      );
      expect(sim.server.deltasSent, greaterThan(0));
      expect(sim.server.connectAttempts, greaterThan(4));
      expect(sim.server.backlogDelivered, greaterThan(0));
      expect(
        sim.backend.staleEventPages + sim.backend.staleSnapshots,
        greaterThan(0),
      );
      expect(report.resyncAcks, greaterThan(0));
      await sim.dispose();
    },
  );

  testWidgets('5 clients x 200 random ops converge with heavy disruptions', (
    tester,
  ) async {
    final sim = Sim(
      tester,
      seed: 424242,
      clients: 5,
      opsPerClient: 200,
      disruptions: true,
    );

    await sim.run();
    await sim.settle();

    final report = verifyRun(sim);
    expectScenarios(sim, report);
    final conflicts = sim.all.fold<int>(
      0,
      (sum, client) => sum + (client.nacks[NackReason.versionConflict] ?? 0),
    );
    expect(conflicts, greaterThan(0));
    expect(report.rejectedBy[NackReason.versionConflict], greaterThan(0));
    await sim.dispose();
  });

  testWidgets('a different seed converges too', (tester) async {
    final sim = Sim(
      tester,
      seed: 99,
      clients: 3,
      opsPerClient: 400,
      disruptions: true,
    );

    await sim.run();
    await sim.settle();

    verifyRun(sim);
    await sim.dispose();
  });

  for (final seed in <int>[977 * 22, 977 * 23]) {
    testWidgets('seed $seed converges when the tail of events is lost', (
      tester,
    ) async {
      final sim = Sim(
        tester,
        seed: seed,
        clients: 3,
        opsPerClient: 80,
        disruptions: true,
      );

      await sim.run();
      await sim.settle();

      verifyRun(sim);
      await sim.dispose();
    });
  }

  for (var i = 0; i < 36; i++) {
    final seed = 5000 + i * 131;
    testWidgets('seed $seed: 3 clients x 70 ops account for every op', (
      tester,
    ) async {
      final sim = Sim(
        tester,
        seed: seed,
        clients: 3,
        opsPerClient: 70,
        disruptions: true,
        remoteRate: 18,
      );

      await sim.run();
      await sim.settle();

      verifyRun(sim);
      await sim.dispose();
    });
  }
}
