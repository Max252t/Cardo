import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/features/board/data/board_gateway.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/data/fake_board_gateway.dart';
import 'package:cardo/features/board/domain/apply_op.dart';
import 'package:cardo/features/board/domain/board_event.dart';
import 'package:cardo/features/board/domain/board_model.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/board_fixtures.dart';
import '../helpers/gateway_probe.dart';

CreateCard _create(String title, {String columnId = colA}) {
  return CreateCard(
    opId: 'c',
    cardId: 'n1',
    columnId: columnId,
    title: title,
    actorId: 'u1',
  );
}

void main() {
  late BoardModel board;

  setUp(() {
    board = makeBoard();
  });

  group('validate MoveCard', () {
    test('accepts a matching version', () {
      expect(
        FakeBoardGateway.validate(board, moveOp('a1', colB, baseVersion: 1)),
        isNull,
      );
    });

    test('version mismatch is a conflict', () {
      expect(
        FakeBoardGateway.validate(board, moveOp('a1', colB, baseVersion: 2)),
        NackReason.versionConflict,
      );
      expect(
        FakeBoardGateway.validate(board, moveOp('b2', colA, baseVersion: 3)),
        NackReason.versionConflict,
      );
    });

    test('unknown card is not found', () {
      expect(
        FakeBoardGateway.validate(board, moveOp('zz', colB)),
        NackReason.notFound,
      );
    });

    test('unknown column is not found', () {
      expect(
        FakeBoardGateway.validate(board, moveOp('a1', 'zz')),
        NackReason.notFound,
      );
    });

    test('archived card is not found', () {
      final archived = applyOp(
        board,
        const ArchiveCard(opId: 'a', cardId: 'a1'),
      );
      expect(
        FakeBoardGateway.validate(archived, moveOp('a1', colB)),
        NackReason.notFound,
      );
    });
  });

  group('validate CreateCard', () {
    test('title of exactly 500 characters is allowed', () {
      expect(FakeBoardGateway.validate(board, _create('x' * 500)), isNull);
    });

    test('title of 501 characters is a validation error', () {
      expect(
        FakeBoardGateway.validate(board, _create('x' * 501)),
        NackReason.validationError,
      );
    });

    test('limit constant is 500', () {
      expect(CardLimits.titleMaxLength, 500);
    });

    test('unknown column is not found', () {
      expect(
        FakeBoardGateway.validate(board, _create('ok', columnId: 'zz')),
        NackReason.notFound,
      );
    });

    test('column check wins over title length', () {
      expect(
        FakeBoardGateway.validate(board, _create('x' * 900, columnId: 'zz')),
        NackReason.notFound,
      );
    });
  });

  group('validate EditCardTitle', () {
    EditCardTitle edit(String cardId, String title) {
      return EditCardTitle(
        opId: 'e',
        cardId: cardId,
        title: title,
        actorId: 'u1',
      );
    }

    test('accepts a normal title', () {
      expect(FakeBoardGateway.validate(board, edit('a1', 'ok')), isNull);
    });

    test('500 ok, 501 too long', () {
      expect(FakeBoardGateway.validate(board, edit('a1', 'y' * 500)), isNull);
      expect(
        FakeBoardGateway.validate(board, edit('a1', 'y' * 501)),
        NackReason.validationError,
      );
    });

    test('missing card is not found', () {
      expect(
        FakeBoardGateway.validate(board, edit('zz', 'ok')),
        NackReason.notFound,
      );
    });

    test('archived card is not found', () {
      final archived = applyOp(
        board,
        const ArchiveCard(opId: 'a', cardId: 'a1'),
      );
      expect(
        FakeBoardGateway.validate(archived, edit('a1', 'ok')),
        NackReason.notFound,
      );
    });
  });

  group('validate ArchiveCard', () {
    test('existing card passes', () {
      expect(
        FakeBoardGateway.validate(
          board,
          const ArchiveCard(opId: 'a', cardId: 'a1'),
        ),
        isNull,
      );
    });

    test('missing card is not found', () {
      expect(
        FakeBoardGateway.validate(
          board,
          const ArchiveCard(opId: 'a', cardId: 'zz'),
        ),
        NackReason.notFound,
      );
    });
  });

  group('submit over the protocol', () {
    FakeBoardGateway gateway({RejectPolicy? rejectWhen}) {
      return FakeBoardGateway(
        confirmDelay: Duration.zero,
        rejectWhen: rejectWhen,
      );
    }

    Future<GatewayProbe> open(FakeBoardGateway fake) async {
      final probe = GatewayProbe(fake);
      await probe.settle();
      addTearDown(probe.dispose);
      return probe;
    }

    test('confirms and advances seq and server board', () async {
      final fake = gateway();
      final probe = await open(fake);
      final start = fake.snapshot().board.seq;
      expect(
        await probe.send(moveOp('c-audit', DemoIds.done, baseVersion: 1)),
        SendOutcome.sent,
      );
      final event = probe.events.single as CardMovedEvent;
      expect(event.seq, start + 1);
      expect(event.opId, 'op');
      expect(event.toColumnId, DemoIds.done);
      expect(fake.serverBoard.seq, start + 1);
      expect(fake.serverBoard.cardById('c-audit')!.columnId, DemoIds.done);
    });

    test('too long title is rejected with the seq', () async {
      final fake = gateway();
      final probe = await open(fake);
      await probe.send(
        CreateCard(
          opId: 'c',
          cardId: 'n',
          columnId: DemoIds.backlog,
          title: 'x' * 501,
          actorId: DemoIds.elena,
        ),
      );
      final rejection = probe.nacks.single.rejection;
      expect(rejection.reason, NackReason.validationError);
      expect(rejection.atSeq, fake.serverBoard.seq);
      expect(fake.serverBoard.cardById('n'), isNull);
      expect(fake.serverBoard.seq, 1284);
    });

    test('not found has no actor and no limit', () async {
      final probe = await open(gateway());
      await probe.send(moveOp('zz', DemoIds.done));
      final rejection = probe.nacks.single.rejection;
      expect(rejection.reason, NackReason.notFound);
      expect(rejection.actorId, isNull);
      expect(rejection.limit, isNull);
    });

    test('a remote move makes the stale base a version conflict', () async {
      final fake = gateway();
      final probe = await open(fake);
      fake.simulateRemoteMove(
        cardId: 'c-audit',
        toColumnId: DemoIds.review,
        actorId: DemoIds.anya,
      );
      await probe.send(moveOp('c-audit', DemoIds.done, baseVersion: 1));
      final rejection = probe.nacks.single.rejection;
      expect(rejection.reason, NackReason.versionConflict);
      expect(rejection.atSeq, 1285);
      final remote = probe.events.single as CardMovedEvent;
      expect(remote.actorId, DemoIds.anya);
    });

    test('a wrong base version is a conflict', () async {
      final probe = await open(gateway());
      await probe.send(moveOp('c-audit', DemoIds.done, baseVersion: 9));
      expect(probe.nacks.single.rejection.reason, NackReason.versionConflict);
    });

    test('rejectWhen overrides validation and stamps seq', () async {
      final fake = gateway(
        rejectWhen: (op) => const OpRejection(reason: NackReason.rateLimited),
      );
      final probe = await open(fake);
      await probe.send(moveOp('c-audit', DemoIds.done, baseVersion: 1));
      final rejection = probe.nacks.single.rejection;
      expect(rejection.reason, NackReason.rateLimited);
      expect(rejection.atSeq, 1284);
      expect(fake.serverBoard.cardById('c-audit')!.columnId, DemoIds.backlog);
    });

    test('rejectWhen returning null lets the op through', () async {
      final probe = await open(gateway(rejectWhen: (op) => null));
      await probe.send(moveOp('c-audit', DemoIds.done, baseVersion: 1));
      expect(probe.events.single, isA<CardMovedEvent>());
      expect(probe.nacks, isEmpty);
    });

    test('a viewer is refused as forbidden', () async {
      final fake = FakeBoardGateway(
        initial: demoBoardSnapshot(currentUserRole: BoardRole.viewer),
        confirmDelay: Duration.zero,
      );
      final probe = await open(fake);
      await probe.send(moveOp('c-audit', DemoIds.done, baseVersion: 1));
      expect(probe.nacks.single.rejection.reason, NackReason.forbidden);
    });

    test('simulateRemoteMove ignores unknown cards', () {
      final fake = gateway();
      fake.simulateRemoteMove(
        cardId: 'zz',
        toColumnId: DemoIds.done,
        actorId: DemoIds.anya,
      );
      expect(fake.serverBoard.seq, 1284);
    });

    test('snapshot exposes the demo session', () {
      final snapshot = gateway().snapshot();
      expect(snapshot.currentUser.userId, DemoIds.elena);
      expect(snapshot.board.title, 'Запуск Cardo 1.0');
      expect(snapshot.board.columns.length, 4);
      expect(snapshot.board.members.map((m) => m.name), <String>[
        'Елена',
        'Максим',
        'Аня',
      ]);
      expect(snapshot.boards.length, 4);
    });
  });
}
