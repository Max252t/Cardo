import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/data/fake_board_gateway.dart';
import 'package:cardo/features/board/domain/apply_op.dart';
import 'package:cardo/features/board/domain/board_model.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_session.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/board_fixtures.dart';

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

  group('submit', () {
    FakeBoardGateway gateway({RejectPolicy? rejectWhen}) {
      return FakeBoardGateway(
        confirmDelay: Duration.zero,
        rejectWhen: rejectWhen,
      );
    }

    test('confirms and advances seq and server board', () async {
      final fake = gateway();
      final start = fake.snapshot().board.seq;
      final outcome = await fake.submit(
        moveOp('c-audit', DemoIds.done, baseVersion: 1),
      );
      expect(outcome, OpConfirmed(seq: start + 1));
      expect(fake.serverBoard.seq, start + 1);
      expect(fake.snapshot().board.cardById('c-audit')!.columnId, DemoIds.done);
    });

    test('too long title is rejected with the limit and seq', () async {
      final fake = gateway();
      final outcome = await fake.submit(
        CreateCard(
          opId: 'c',
          cardId: 'n',
          columnId: DemoIds.backlog,
          title: 'x' * 501,
          actorId: DemoIds.elena,
        ),
      );
      final rejection = (outcome as OpRejected).rejection;
      expect(rejection.reason, NackReason.validationError);
      expect(rejection.limit, 500);
      expect(rejection.atSeq, fake.serverBoard.seq);
      expect(fake.serverBoard.cardById('n'), isNull);
      expect(fake.serverBoard.seq, 1284);
    });

    test('not found has no actor and no limit', () async {
      final fake = gateway();
      final outcome = await fake.submit(moveOp('zz', DemoIds.done));
      final rejection = (outcome as OpRejected).rejection;
      expect(rejection.reason, NackReason.notFound);
      expect(rejection.actorId, isNull);
      expect(rejection.limit, isNull);
    });

    test('version conflict reports the last mover', () async {
      final fake = gateway();
      fake.simulateRemoteMove(
        cardId: 'c-audit',
        toColumnId: DemoIds.review,
        actorId: DemoIds.anya,
      );
      final outcome = await fake.submit(
        moveOp('c-audit', DemoIds.done, baseVersion: 1),
      );
      final rejection = (outcome as OpRejected).rejection;
      expect(rejection.reason, NackReason.versionConflict);
      expect(rejection.actorId, DemoIds.anya);
      expect(rejection.atSeq, 1285);
    });

    test('version conflict falls back to updatedBy', () async {
      final fake = gateway();
      final outcome = await fake.submit(
        moveOp('c-audit', DemoIds.done, baseVersion: 9),
      );
      expect((outcome as OpRejected).rejection.actorId, DemoIds.elena);
    });

    test('rejectWhen overrides validation and stamps seq', () async {
      final fake = gateway(
        rejectWhen: (op) => const OpRejection(reason: NackReason.rateLimited),
      );
      final outcome = await fake.submit(
        moveOp('c-audit', DemoIds.done, baseVersion: 1),
      );
      final rejection = (outcome as OpRejected).rejection;
      expect(rejection.reason, NackReason.rateLimited);
      expect(rejection.atSeq, 1284);
      expect(fake.serverBoard.cardById('c-audit')!.columnId, DemoIds.backlog);
    });

    test('rejectWhen returning null lets the op through', () async {
      final fake = gateway(rejectWhen: (op) => null);
      final outcome = await fake.submit(
        moveOp('c-audit', DemoIds.done, baseVersion: 1),
      );
      expect(outcome, isA<OpConfirmed>());
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
