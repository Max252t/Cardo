import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/core/realtime/connection_status.dart';
import 'package:cardo/features/auth/domain/user.dart';
import 'package:cardo/features/auth/presentation/auth_providers.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/data/board_gateway.dart';
import 'package:cardo/features/board/data/fake_board_gateway.dart';
import 'package:cardo/features/board/data/sync_signal.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_session.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/domain/card_draft.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/features/board/presentation/board_route_page.dart';
import 'package:cardo/features/board/presentation/card_drafts.dart';
import 'package:cardo/features/board/presentation/card_sheet_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/board_fixtures.dart';

DateTime clock = DateTime.utc(2026, 1, 1, 12);

class LiveUserSource extends Notifier<CurrentUser> {
  LiveUserSource(this.initial);

  final CurrentUser initial;

  @override
  CurrentUser build() => initial;

  void set(CurrentUser user) => state = user;
}

typedef Opened = ({ProviderContainer c, FakeBoardGateway g});

Opened open({RejectPolicy? rejectWhen, BoardSyncConfig? config}) {
  final g = FakeBoardGateway(
    confirmDelay: Duration.zero,
    rejectWhen: rejectWhen,
  );
  final ids = IdSequence();
  final c = ProviderContainer(
    overrides: [
      boardGatewayProvider.overrideWithValue(g),
      idGeneratorProvider.overrideWithValue(ids.call),
      nowProvider.overrideWithValue(() => clock),
      boardSyncConfigProvider.overrideWithValue(
        config ??
            const BoardSyncConfig(
              nackHold: Duration(milliseconds: 100),
              retryDelay: Duration(milliseconds: 50),
              maxInternalRetries: 2,
            ),
      ),
    ],
  );
  c.listen(boardNotifierProvider, (_, _) {});
  return (c: c, g: g);
}

BoardSyncState read(ProviderContainer c) => c.read(boardNotifierProvider);

Future<void> run(WidgetTester t, int ms) => t.pump(Duration(milliseconds: ms));

void main() {
  setUp(() => clock = DateTime.utc(2026, 1, 1, 12));

  group('pending older than 24 hours', () {
    testWidgets('are dropped at ready together with their dependants', (
      t,
    ) async {
      final o = open();
      await run(t, 10);
      o.g.server.dropConnections();
      await run(t, 1);
      final n = o.c.read(boardNotifierProvider.notifier);
      n.createCard(columnId: DemoIds.backlog, title: 'Old');
      clock = clock.add(const Duration(hours: 2));
      n.editCardTitle(cardId: 'id-1', title: 'Old edited');
      clock = clock.add(const Duration(hours: 21));
      n.createCard(columnId: DemoIds.backlog, title: 'Young');
      expect(read(o.c).pending, hasLength(3));
      clock = clock.add(const Duration(hours: 2));

      await run(t, 700);

      expect(o.g.server.receivedOps.map((op) => op.opId), ['id-3']);
      expect(read(o.c).pending, isEmpty);
      final titles = read(o.c).confirmed.cards.map((card) => card.title);
      expect(titles, contains('Young'));
      expect(titles, isNot(contains('Old')));
      expect(titles, isNot(contains('Old edited')));
      o.c.dispose();
    });

    testWidgets('an operation just under 24 hours is still sent', (t) async {
      final o = open();
      await run(t, 10);
      o.g.server.dropConnections();
      await run(t, 1);
      o.c
          .read(boardNotifierProvider.notifier)
          .createCard(columnId: DemoIds.backlog, title: 'Almost');
      clock = clock.add(const Duration(hours: 23, minutes: 59));

      await run(t, 700);

      expect(o.g.server.receivedOps.map((op) => op.opId), ['id-0']);
      expect(read(o.c).pending, isEmpty);
      o.c.dispose();
    });
  });

  group('operations accumulate while the link is down', () {
    testWidgets('during reconnecting they queue and go out in order', (
      t,
    ) async {
      final o = open();
      await run(t, 10);
      o.g.server.dropConnections();
      await run(t, 1);
      expect(read(o.c).connection, ConnectionStatus.reconnecting);
      final n = o.c.read(boardNotifierProvider.notifier);

      n.createCard(columnId: DemoIds.backlog, title: 'One');
      n.moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);
      n.editCardTitle(cardId: 'c-ci', title: 'Renamed');

      expect(
        read(o.c).pending.map((item) => item.status),
        everyElement(PendingOpStatus.queued),
      );
      expect(o.g.server.receivedOps, isEmpty);
      await run(t, 700);

      expect(o.g.server.receivedOps.map((op) => op.opId), [
        'id-0',
        'id-2',
        'id-3',
      ]);
      expect(read(o.c).pending, isEmpty);
      expect(read(o.c).connection, ConnectionStatus.connected);
      expect(read(o.c).confirmed.cardById('c-ci')!.title, 'Renamed');
      o.c.dispose();
    });

    testWidgets('while offline they queue and go out after connect', (t) async {
      final o = open();
      await run(t, 10);
      await o.g.close();
      await run(t, 10);
      expect(read(o.c).connection, ConnectionStatus.offline);
      final n = o.c.read(boardNotifierProvider.notifier);

      n.moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);
      n.moveCard(cardId: 'c-ci', toColumnId: DemoIds.backlog);

      expect(read(o.c).pending, hasLength(2));
      expect(o.g.server.receivedOps, isEmpty);
      o.g.connect();
      await run(t, 50);

      expect(o.g.server.receivedOps.map((op) => op.opId), ['id-0', 'id-1']);
      expect(read(o.c).pending, isEmpty);
      o.c.dispose();
    });

    testWidgets('the view shows queued operations optimistically', (t) async {
      final o = open();
      await run(t, 10);
      o.g.server.dropConnections();
      await run(t, 1);

      o.c
          .read(boardNotifierProvider.notifier)
          .moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);

      expect(read(o.c).view.cardById('c-audit')!.columnId, DemoIds.done);
      expect(
        read(o.c).confirmed.cardById('c-audit')!.columnId,
        isNot(DemoIds.done),
      );
      await run(t, 700);
      o.c.dispose();
    });

    testWidgets('the countdown reaches the state while reconnecting', (
      t,
    ) async {
      final o = open();
      await run(t, 10);
      o.g.server.failNextConnections(3);
      o.g.server.dropConnections();
      await run(t, 1);
      expect(read(o.c).reconnectSeconds, 1);
      await run(t, 1700);
      expect(read(o.c).connection, ConnectionStatus.reconnecting);
      expect(read(o.c).reconnectSeconds, 2);
      await run(t, 1000);
      expect(read(o.c).reconnectSeconds, 1);
      await run(t, 900);
      expect(read(o.c).reconnectSeconds, 4);
      await run(t, 4000);
      expect(read(o.c).connection, ConnectionStatus.connected);
      expect(read(o.c).reconnectSeconds, isNull);
      o.c.dispose();
    });
  });

  group('role changes on the fly', () {
    testWidgets('a viewer cannot enqueue anything, an editor again can', (
      t,
    ) async {
      final o = open();
      await run(t, 10);
      final n = o.c.read(boardNotifierProvider.notifier);
      expect(o.c.read(canEditBoardProvider), isTrue);

      o.g.server.changeRole(DemoIds.elena, BoardRole.viewer);
      await run(t, 10);

      expect(o.c.read(currentRoleProvider), BoardRole.viewer);
      expect(o.c.read(canEditBoardProvider), isFalse);
      n.moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);
      n.moveCardToIndex(cardId: 'c-audit', toColumnId: DemoIds.done, index: 0);
      n.moveCardToColumnEnd(cardId: 'c-audit', toColumnId: DemoIds.done);
      n.createCard(columnId: DemoIds.backlog, title: 'x');
      n.editCardTitle(cardId: 'c-ci', title: 'x');
      n.archiveCard('c-ci');
      expect(
        n.editCardDescription(
          cardId: 'c-ci',
          description: 'x',
          baseDescriptionVersion: 1,
        ),
        isNull,
      );
      expect(read(o.c).pending, isEmpty);
      expect(o.g.server.receivedOps, isEmpty);

      o.g.server.changeRole(DemoIds.elena, BoardRole.editor);
      await run(t, 10);
      expect(o.c.read(canEditBoardProvider), isTrue);
      n.moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);
      await run(t, 10);

      expect(o.g.server.receivedOps, hasLength(1));
      expect(read(o.c).pending, isEmpty);
      o.c.dispose();
    });

    testWidgets('an operation already in flight gets a forbidden nack', (
      t,
    ) async {
      final o = open();
      await run(t, 10);
      o.g.server.dropConnections();
      await run(t, 1);
      o.c
          .read(boardNotifierProvider.notifier)
          .moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);
      o.g.server.changeRole(DemoIds.elena, BoardRole.viewer);

      await run(t, 700);

      expect(read(o.c).pending, isEmpty);
      expect(
        read(o.c).confirmed.cardById('c-audit')!.columnId,
        isNot(DemoIds.done),
      );
      expect(o.c.read(canEditBoardProvider), isFalse);
      o.c.dispose();
    });
  });

  group('the board ends', () {
    testWidgets(
      'member.removed for me ends as removed and stops reconnecting',
      (t) async {
        final o = open();
        await run(t, 10);

        o.g.server.removeMember(DemoIds.elena);
        await run(t, 60000);

        expect(read(o.c).ended, BoardEndReason.removed);
        expect(read(o.c).connection, ConnectionStatus.offline);
        expect(o.g.server.connectAttempts, 1);
        expect(o.g.server.openConnections, 0);
        o.c.dispose();
      },
    );

    testWidgets('member.removed for someone else does not end the board', (
      t,
    ) async {
      final o = open();
      await run(t, 10);

      o.g.server.removeMember(DemoIds.maxim);
      await run(t, 10);

      expect(read(o.c).ended, isNull);
      expect(read(o.c).confirmed.memberById(DemoIds.maxim), isNull);
      expect(read(o.c).connection, ConnectionStatus.connected);
      o.c.dispose();
    });

    testWidgets('board.deleted ends as boardDeleted', (t) async {
      final o = open();
      await run(t, 10);

      o.g.server.deleteBoard();
      await run(t, 60000);

      expect(read(o.c).ended, BoardEndReason.boardDeleted);
      expect(o.g.server.connectAttempts, 1);
      o.c.dispose();
    });

    testWidgets('close 4003 without an event ends as removed', (t) async {
      final o = open();
      await run(t, 10);

      o.g.server.closeConnections(4003);
      await run(t, 60000);

      expect(read(o.c).ended, BoardEndReason.removed);
      expect(o.g.server.connectAttempts, 1);
      o.c.dispose();
    });

    testWidgets('close 4004 without an event ends as boardDeleted', (t) async {
      final o = open();
      await run(t, 10);

      o.g.server.closeConnections(4004);
      await run(t, 60000);

      expect(read(o.c).ended, BoardEndReason.boardDeleted);
      o.c.dispose();
    });

    testWidgets('after the end connection signals no longer change the state', (
      t,
    ) async {
      final g = ControlledGateway();
      final c = makeContainer(gateway: g);
      c.listen(boardNotifierProvider, (_, _) {});
      g.emit(const EndedSignal(BoardEndReason.removed));

      g.emit(const ConnectionSignal(ConnectionStatus.syncing));
      g.emit(const ReadySignal());

      expect(read(c).ended, BoardEndReason.removed);
      expect(read(c).connection, ConnectionStatus.offline);
      expect(g.closes, greaterThan(0));
      c.dispose();
    });

    testWidgets('ending twice keeps the first reason', (t) async {
      final g = ControlledGateway();
      final c = makeContainer(gateway: g);
      c.listen(boardNotifierProvider, (_, _) {});

      g.emit(const EndedSignal(BoardEndReason.boardDeleted));
      g.emit(const EndedSignal(BoardEndReason.removed));

      expect(read(c).ended, BoardEndReason.boardDeleted);
      c.dispose();
    });

    testWidgets('once removed the user can no longer edit', (t) async {
      final o = open();
      await run(t, 10);
      o.g.server.removeMember(DemoIds.elena);
      await run(t, 10);

      o.c
          .read(boardNotifierProvider.notifier)
          .moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);

      expect(read(o.c).pending, isEmpty);
      o.c.dispose();
    });
  });

  group('connection states from the gateway', () {
    testWidgets('syncing, reconnecting with seconds and ready', (t) async {
      final g = ControlledGateway();
      final c = makeContainer(gateway: g);
      c.listen(boardNotifierProvider, (_, _) {});

      g.emit(const ConnectionSignal(ConnectionStatus.syncing));
      expect(read(c).connection, ConnectionStatus.syncing);
      g.emit(
        const ConnectionSignal(
          ConnectionStatus.reconnecting,
          reconnectSeconds: 7,
        ),
      );
      expect(read(c).connection, ConnectionStatus.reconnecting);
      expect(read(c).reconnectSeconds, 7);
      g.emit(
        const ConnectionSignal(
          ConnectionStatus.reconnecting,
          reconnectSeconds: 6,
        ),
      );
      expect(read(c).reconnectSeconds, 6);
      g.emit(const ReadySignal());
      expect(read(c).connection, ConnectionStatus.connected);
      expect(read(c).reconnectSeconds, isNull);
      g.emit(const ConnectionSignal(ConnectionStatus.offline));
      expect(read(c).connection, ConnectionStatus.offline);
      c.dispose();
    });

    testWidgets('operations are not dispatched while syncing', (t) async {
      final g = ControlledGateway();
      final c = makeContainer(gateway: g);
      c.listen(boardNotifierProvider, (_, _) {});
      g.emit(const ConnectionSignal(ConnectionStatus.syncing));

      c
          .read(boardNotifierProvider.notifier)
          .moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);

      expect(g.calls, isEmpty);
      expect(read(c).pending.single.status, PendingOpStatus.queued);
      g.emit(const ReadySignal());
      expect(g.calls, hasLength(1));
      expect(read(c).pending.single.status, PendingOpStatus.sent);
      c.dispose();
    });

    testWidgets('a gateway that cannot send leaves the op queued', (t) async {
      final g = ControlledGateway();
      final c = makeContainer(gateway: g);
      c.listen(boardNotifierProvider, (_, _) {});
      g.emit(const ReadySignal());
      g.nextOutcome = SendOutcome.notConnected;

      c
          .read(boardNotifierProvider.notifier)
          .moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);

      expect(read(c).pending.single.status, PendingOpStatus.queued);
      c.dispose();
    });

    testWidgets('retryConnection forwards to the gateway', (t) async {
      final g = ControlledGateway();
      final c = makeContainer(gateway: g);
      c.listen(boardNotifierProvider, (_, _) {});

      c.read(boardNotifierProvider.notifier).retryConnection();

      expect(g.retries, 1);
      c.dispose();
    });

    testWidgets('disposing the container closes the gateway', (t) async {
      final g = ControlledGateway();
      final c = makeContainer(gateway: g);
      c.listen(boardNotifierProvider, (_, _) {});
      expect(g.connects, 1);

      c.dispose();

      expect(g.closes, 1);
    });
  });

  group('presence', () {
    PresenceUser user(String id) =>
        PresenceUser(userId: id, name: id, avatarColor: '#111111');

    List<String> online(ProviderContainer c) => [
      for (final member in c.read(onlineMembersProvider)) member.userId,
    ];

    testWidgets('list replaces the set and removes duplicates', (t) async {
      final g = ControlledGateway();
      final c = makeContainer(gateway: g);
      c.listen(boardNotifierProvider, (_, _) {});

      g.emit(
        PresenceListSignal([
          user(DemoIds.maxim),
          user(DemoIds.maxim),
          user(DemoIds.anya),
        ]),
      );

      expect(online(c), [DemoIds.maxim, DemoIds.anya]);
      g.emit(PresenceListSignal([user(DemoIds.elena)]));
      expect(online(c), [DemoIds.elena]);
      c.dispose();
    });

    testWidgets('join adds once and leave removes', (t) async {
      final g = ControlledGateway();
      final c = makeContainer(gateway: g);
      c.listen(boardNotifierProvider, (_, _) {});
      g.emit(PresenceListSignal([user(DemoIds.elena)]));

      g.emit(PresenceJoinSignal(user(DemoIds.maxim)));
      g.emit(PresenceJoinSignal(user(DemoIds.maxim)));
      expect(online(c), [DemoIds.elena, DemoIds.maxim]);
      g.emit(const PresenceLeaveSignal(DemoIds.maxim));
      g.emit(const PresenceLeaveSignal(DemoIds.maxim));
      g.emit(const PresenceLeaveSignal('nobody'));

      expect(online(c), [DemoIds.elena]);
      c.dispose();
    });

    testWidgets('users who are not board members are not shown', (t) async {
      final g = ControlledGateway();
      final c = makeContainer(gateway: g);
      c.listen(boardNotifierProvider, (_, _) {});

      g.emit(PresenceListSignal([user('stranger'), user(DemoIds.maxim)]));

      expect(online(c), [DemoIds.maxim]);
      c.dispose();
    });

    testWidgets('reconnecting and offline clear it, a new list restores it', (
      t,
    ) async {
      final g = ControlledGateway();
      final c = makeContainer(gateway: g);
      c.listen(boardNotifierProvider, (_, _) {});
      g.emit(PresenceListSignal([user(DemoIds.maxim), user(DemoIds.anya)]));

      g.emit(
        const ConnectionSignal(
          ConnectionStatus.reconnecting,
          reconnectSeconds: 2,
        ),
      );
      expect(online(c), isEmpty);
      g.emit(PresenceListSignal([user(DemoIds.maxim)]));
      g.emit(const ConnectionSignal(ConnectionStatus.offline));
      expect(online(c), isEmpty);
      g.emit(PresenceListSignal([user(DemoIds.anya)]));
      expect(online(c), [DemoIds.anya]);
      c.dispose();
    });

    testWidgets('a real reconnect empties it and the handshake refills it', (
      t,
    ) async {
      final o = open();
      await run(t, 10);
      expect(online(o.c), hasLength(3));

      o.g.server.dropConnections();
      await run(t, 1);
      expect(online(o.c), isEmpty);
      await run(t, 700);

      expect(online(o.c), hasLength(3));
      o.c.dispose();
    });

    testWidgets('syncing does not clear presence', (t) async {
      final g = ControlledGateway();
      final c = makeContainer(gateway: g);
      c.listen(boardNotifierProvider, (_, _) {});
      g.emit(PresenceListSignal([user(DemoIds.maxim)]));

      g.emit(const ConnectionSignal(ConnectionStatus.syncing));

      expect(online(c), [DemoIds.maxim]);
      c.dispose();
    });
  });

  group('the current user comes live from the session', () {
    final first = CurrentUser(
      userId: DemoIds.elena,
      name: 'Elena',
      email: 'e@x.test',
      avatarColor: '#111111',
    );

    testWidgets('liveUserProvider wins over the snapshot user', (t) async {
      final g = ControlledGateway();
      final c = ProviderContainer(
        overrides: [
          boardGatewayProvider.overrideWithValue(g),
          liveUserProvider.overrideWithValue(first),
        ],
      );

      expect(c.read(currentUserProvider), first);
      c.dispose();
    });

    testWidgets('a null live user falls back to the snapshot user', (t) async {
      final g = ControlledGateway();
      final c = ProviderContainer(
        overrides: [boardGatewayProvider.overrideWithValue(g)],
      );

      expect(c.read(currentUserProvider), g.snapshot().currentUser);
      c.dispose();
    });

    testWidgets('a profile change flows into currentUserProvider', (t) async {
      final session = NotifierProvider<LiveUserSource, CurrentUser>(
        () => LiveUserSource(first),
      );
      final g = ControlledGateway();
      final c = ProviderContainer(
        overrides: [
          boardGatewayProvider.overrideWithValue(g),
          liveUserProvider.overrideWith((ref) => ref.watch(session)),
        ],
      );
      c.listen(currentUserProvider, (_, _) {});
      expect(c.read(currentUserProvider).avatarColor, '#111111');

      c
          .read(session.notifier)
          .set(
            CurrentUser(
              userId: DemoIds.elena,
              name: 'Lena',
              email: 'e@x.test',
              avatarColor: '#222222',
            ),
          );

      expect(c.read(currentUserProvider).name, 'Lena');
      expect(c.read(currentUserProvider).avatarColor, '#222222');
      c.dispose();
    });

    testWidgets('a live user who is not a member cannot edit', (t) async {
      final g = ControlledGateway();
      final c = ProviderContainer(
        overrides: [
          boardGatewayProvider.overrideWithValue(g),
          liveUserProvider.overrideWithValue(
            CurrentUser(
              userId: 'stranger',
              name: 'S',
              email: 's@x.test',
              avatarColor: '#333333',
            ),
          ),
        ],
      );

      expect(c.read(currentRoleProvider), BoardRole.viewer);
      expect(c.read(canEditBoardProvider), isFalse);
      c.dispose();
    });

    testWidgets('sessionCurrentUserProvider maps the signed in user', (
      t,
    ) async {
      final user = User(
        id: 'u-1',
        email: 'u1@x.test',
        displayName: 'User One',
        avatarColor: '#444444',
        createdAt: DateTime.utc(2026),
      );
      final signedIn = ProviderContainer(
        overrides: [sessionUserProvider.overrideWithValue(user)],
      );
      final signedOut = ProviderContainer(
        overrides: [sessionUserProvider.overrideWithValue(null)],
      );

      expect(
        signedIn.read(sessionCurrentUserProvider),
        const CurrentUser(
          userId: 'u-1',
          name: 'User One',
          email: 'u1@x.test',
          avatarColor: '#444444',
        ),
      );
      expect(signedOut.read(sessionCurrentUserProvider), isNull);
      signedIn.dispose();
      signedOut.dispose();
    });
  });

  group('internal and rate limited nacks', () {
    testWidgets('internal is retried with the same op_id and then succeeds', (
      t,
    ) async {
      var attempts = 0;
      final o = open(
        rejectWhen: (op) => ++attempts <= 2
            ? const OpRejection(reason: NackReason.internal)
            : null,
      );
      await run(t, 10);

      o.c
          .read(boardNotifierProvider.notifier)
          .moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);
      await run(t, 10);
      expect(read(o.c).pending.single.failedAttempts, 1);
      await run(t, 60);
      await run(t, 60);
      await run(t, 10);

      expect(o.g.server.receivedOps.map((op) => op.opId), [
        'id-0',
        'id-0',
        'id-0',
      ]);
      expect(read(o.c).pending, isEmpty);
      expect(read(o.c).confirmed.cardById('c-audit')!.columnId, DemoIds.done);
      o.c.dispose();
    });

    testWidgets('internal beyond the retry budget becomes a rejection', (
      t,
    ) async {
      final o = open(
        rejectWhen: (op) => const OpRejection(reason: NackReason.internal),
      );
      await run(t, 10);

      o.c
          .read(boardNotifierProvider.notifier)
          .moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);
      await run(t, 10);
      await run(t, 60);
      await run(t, 60);

      expect(o.g.server.receivedOps, hasLength(3));
      expect(o.g.server.receivedOps.map((op) => op.opId).toSet(), {'id-0'});
      expect(read(o.c).pending.single.isRejected, isTrue);
      expect(read(o.c).pending.single.rejection!.reason, NackReason.internal);
      await run(t, 300);
      expect(read(o.c).pending, isEmpty);
      o.c.dispose();
    });

    testWidgets('rate_limited is retried with the same op id and never shown', (
      t,
    ) async {
      var attempts = 0;
      final o = open(
        rejectWhen: (op) => ++attempts <= 2
            ? const OpRejection(reason: NackReason.rateLimited)
            : null,
      );
      await run(t, 10);
      final history = <BoardSyncState>[];
      o.c.listen(boardNotifierProvider, (_, next) => history.add(next));

      o.c
          .read(boardNotifierProvider.notifier)
          .moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);
      await run(t, 10);
      expect(read(o.c).pending.single.isRejected, isFalse);
      await run(t, 1100);
      await run(t, 1100);

      expect(read(o.c).pending, isEmpty);
      expect(o.g.server.receivedOps.map((op) => op.opId).toSet(), {'id-0'});
      expect(o.g.server.receivedOps, hasLength(3));
      expect(history.any((state) => state.rejected.isNotEmpty), isFalse);
      expect(read(o.c).confirmed.cardById('c-audit')!.columnId, DemoIds.done);
      o.c.dispose();
    });

    testWidgets('rate_limited that never lets the op through is rejected', (
      t,
    ) async {
      final o = open(
        rejectWhen: (op) => const OpRejection(reason: NackReason.rateLimited),
      );
      await run(t, 10);
      final seen = <OpRejection>[];
      o.c.listen(boardNotifierProvider, (_, next) {
        seen.addAll(next.rejected.map((item) => item.rejection!));
      });

      o.c
          .read(boardNotifierProvider.notifier)
          .moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);
      for (var i = 0; i < 40; i++) {
        await run(t, 1000);
      }

      expect(seen.first.reason, NackReason.rateLimited);
      expect(o.g.server.receivedOps, hasLength(31));
      expect(read(o.c).pending, isEmpty);
      o.c.dispose();
    });

    testWidgets('resync_required drops the op without a rejection', (t) async {
      final o = open();
      await run(t, 10);
      o.g.server.resyncRequiredFor('id-0');

      o.c
          .read(boardNotifierProvider.notifier)
          .moveCard(cardId: 'c-audit', toColumnId: DemoIds.done);
      await run(t, 10);

      expect(read(o.c).pending, isEmpty);
      expect(read(o.c).rejected, isEmpty);
      expect(o.g.server.snapshotLoads, 1);
      o.c.dispose();
    });
  });

  group('drafts and description conflicts driven by events', () {
    const card = DemoIds.handshakeCard;

    CardDraft? draft(ProviderContainer c) => c.read(cardDraftsProvider)[card];

    Opened openDrafts() {
      final o = open();
      o.c.read(cardDraftsProvider);
      return o;
    }

    EditCardDescription remoteEdit(String text, int base) =>
        EditCardDescription(
          opId: 'remote-$text',
          cardId: card,
          description: text,
          baseDescriptionVersion: base,
          actorId: DemoIds.maxim,
        );

    testWidgets('a live remote edit while typing raises a conflict', (t) async {
      final o = openDrafts();
      await run(t, 10);
      o.c.read(cardDraftsProvider.notifier).edit(card, 'my words');
      final base = draft(o.c)!.baseDescriptionVersion;

      o.g.server.commitRemote(
        remoteEdit('their words', base),
        actorId: DemoIds.maxim,
      );
      await run(t, 10);

      expect(draft(o.c)!.conflict, isTrue);
      expect(draft(o.c)!.text, 'my words');
      expect(draft(o.c)!.conflictActorId, DemoIds.maxim);
      final sheet = o.c.read(cardSheetProvider(card))!;
      expect(sheet.conflict, isNotNull);
      expect(sheet.conflict!.actorName, isNotNull);
      expect(sheet.canSave, isFalse);
      o.c.dispose();
    });

    testWidgets('a remote edit with the same text clears the draft', (t) async {
      final o = openDrafts();
      await run(t, 10);
      o.c.read(cardDraftsProvider.notifier).edit(card, 'same');
      final base = draft(o.c)!.baseDescriptionVersion;

      o.g.server.commitRemote(remoteEdit('same', base), actorId: DemoIds.maxim);
      await run(t, 10);

      expect(draft(o.c), isNull);
      o.c.dispose();
    });

    testWidgets('an edit to another card does not disturb the draft', (
      t,
    ) async {
      final o = openDrafts();
      await run(t, 10);
      o.c.read(cardDraftsProvider.notifier).edit(card, 'my words');

      o.g.server.commitRemote(
        const EditCardDescription(
          opId: 'other',
          cardId: 'c-audit',
          description: 'elsewhere',
          baseDescriptionVersion: 1,
          actorId: DemoIds.maxim,
        ),
        actorId: DemoIds.maxim,
      );
      await run(t, 10);

      expect(draft(o.c)!.conflict, isFalse);
      o.c.dispose();
    });

    testWidgets('a nack arrives after the remote event and can be resolved', (
      t,
    ) async {
      final o = openDrafts();
      await run(t, 10);
      final n = o.c.read(cardDraftsProvider.notifier);
      n.edit(card, 'mine');
      final base = draft(o.c)!.baseDescriptionVersion;
      o.g.server.commitRemote(
        remoteEdit('theirs', base),
        actorId: DemoIds.maxim,
        deliver: false,
      );

      n.save(card);
      await run(t, 10);

      expect(draft(o.c)!.conflict, isTrue);
      expect(draft(o.c)!.conflictAtSeq, isNotNull);
      expect(
        read(o.c).lastSeq,
        greaterThanOrEqualTo(draft(o.c)!.conflictAtSeq!),
      );
      expect(o.c.read(cardSheetProvider(card))!.conflict!.resolvable, isTrue);

      n.overwrite(card);
      await run(t, 300);

      expect(o.g.server.board.cardById(card)!.description, 'mine');
      expect(draft(o.c), isNull);
      expect(read(o.c).pending, isEmpty);
      o.c.dispose();
    });

    testWidgets('a nack naming a later seq waits for the events', (t) async {
      final g = ControlledGateway();
      final c = makeContainer(gateway: g);
      c.listen(boardNotifierProvider, (_, _) {});
      c.read(cardDraftsProvider);
      g.emit(const ReadySignal());
      c.read(cardDraftsProvider.notifier).edit(card, 'mine');
      c.read(cardDraftsProvider.notifier).save(card);
      g.calls.single.rejectWith(
        const OpRejection(reason: NackReason.versionConflict, atSeq: 1290),
      );
      await run(t, 5);
      expect(c.read(cardSheetProvider(card))!.conflict!.resolvable, isFalse);

      g.pushDescription(card, 'theirs', descriptionVersion: 2, seq: 1285);
      await run(t, 5);

      expect(c.read(cardSheetProvider(card))!.conflict!.resolvable, isTrue);
      await run(t, 300);
      c.dispose();
    });
  });
}
