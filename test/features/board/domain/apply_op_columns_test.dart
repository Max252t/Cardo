import 'package:cardo/features/board/domain/apply_op.dart';
import 'package:cardo/features/board/domain/board_model.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/board_fixtures.dart';

List<String> order(BoardModel board) =>
    board.orderedColumns.map((column) => column.id).toList();

void main() {
  late BoardModel board;

  setUp(() => board = makeBoard());

  group('CreateColumn', () {
    test('without anchors appends the column at the end', () {
      final result = applyOp(
        board,
        const CreateColumn(opId: 'o', columnId: 'col-n', title: 'QA'),
      );

      expect(order(result), [colA, colB, colC, 'col-n']);
      final column = result.columnById('col-n')!;
      expect(column.title, 'QA');
      expect(column.version, 1);
      expect(result.orderedColumns.last.marker, ColumnMarker.done);
      expect(result.columnById(colC)!.marker, ColumnMarker.review);
    });

    test('afterId puts it right behind the anchor', () {
      final result = applyOp(
        board,
        const CreateColumn(
          opId: 'o',
          columnId: 'col-n',
          title: 'QA',
          afterId: colA,
        ),
      );

      expect(order(result), [colA, 'col-n', colB, colC]);
    });

    test('beforeId puts it right ahead of the anchor', () {
      final result = applyOp(
        board,
        const CreateColumn(
          opId: 'o',
          columnId: 'col-n',
          title: 'QA',
          beforeId: colA,
        ),
      );

      expect(order(result), ['col-n', colA, colB, colC]);
      expect(result.orderedColumns.first.marker, ColumnMarker.backlog);
    });

    test('an unknown anchor falls back to the end', () {
      final result = applyOp(
        board,
        const CreateColumn(
          opId: 'o',
          columnId: 'col-n',
          title: 'QA',
          afterId: 'ghost',
        ),
      );

      expect(order(result).last, 'col-n');
    });

    test('creating an existing column changes nothing', () {
      final result = applyOp(
        board,
        const CreateColumn(opId: 'o', columnId: colB, title: 'Again'),
      );

      expect(result.columns, board.columns);
    });
  });

  group('RenameColumn', () {
    test('changes the title and bumps the version', () {
      final result = applyOp(
        board,
        const RenameColumn(opId: 'o', columnId: colB, title: 'Doing'),
      );

      expect(result.columnById(colB)!.title, 'Doing');
      expect(result.columnById(colB)!.version, 2);
      expect(result.columnById(colA)!.version, 1);
    });

    test('an unknown column is ignored', () {
      final result = applyOp(
        board,
        const RenameColumn(opId: 'o', columnId: 'ghost', title: 'x'),
      );

      expect(result.columns, board.columns);
    });
  });

  group('MoveColumn', () {
    test('afterId the last column moves it to the end', () {
      final result = applyOp(
        board,
        const MoveColumn(
          opId: 'o',
          columnId: colA,
          baseVersion: 1,
          afterId: colC,
        ),
      );

      expect(order(result), [colB, colC, colA]);
      expect(result.columnById(colA)!.version, 2);
    });

    test('beforeId the first column moves it to the front', () {
      final result = applyOp(
        board,
        const MoveColumn(
          opId: 'o',
          columnId: colC,
          baseVersion: 1,
          beforeId: colA,
        ),
      );

      expect(order(result), [colC, colA, colB]);
    });

    test('between two neighbours gets a rank strictly between them', () {
      final result = applyOp(
        board,
        const MoveColumn(
          opId: 'o',
          columnId: colC,
          baseVersion: 1,
          afterId: colA,
        ),
      );

      expect(order(result), [colA, colC, colB]);
      final ranks = result.orderedColumns.map((c) => c.rank).toList();
      expect(ranks[0].compareTo(ranks[1]), lessThan(0));
      expect(ranks[1].compareTo(ranks[2]), lessThan(0));
    });

    test('markers follow the new order', () {
      final result = applyOp(
        board,
        const MoveColumn(
          opId: 'o',
          columnId: colA,
          baseVersion: 1,
          afterId: colC,
        ),
      );

      expect(result.orderedColumns.first.marker, ColumnMarker.backlog);
      expect(result.orderedColumns.last.marker, ColumnMarker.done);
      expect(result.orderedColumns.last.id, colA);
    });

    test('an unknown column is ignored', () {
      final result = applyOp(
        board,
        const MoveColumn(opId: 'o', columnId: 'ghost', baseVersion: 1),
      );

      expect(result.columns, board.columns);
    });
  });

  group('ArchiveColumn', () {
    test('removes the column and archives all of its cards', () {
      final result = applyOp(
        board,
        const ArchiveColumn(opId: 'o', columnId: colA),
      );

      expect(result.columnById(colA), isNull);
      for (final id in ['a1', 'a2', 'a3']) {
        expect(result.cardById(id)!.archived, isTrue, reason: id);
      }
      expect(ids(result, colB), ['b1', 'b2']);
      expect(order(result), [colB, colC]);
      expect(result.orderedColumns.first.marker, ColumnMarker.backlog);
    });

    test('an unknown column is ignored', () {
      final result = applyOp(
        board,
        const ArchiveColumn(opId: 'o', columnId: 'ghost'),
      );

      expect(result.columns, board.columns);
      expect(result.cards, board.cards);
    });
  });

  group('canApplyOp', () {
    test('card operations need an active card and a known column', () {
      expect(
        canApplyOp(
          board,
          const MoveCard(
            opId: 'o',
            cardId: 'a1',
            toColumnId: colB,
            baseVersion: 1,
          ),
        ),
        isTrue,
      );
      expect(
        canApplyOp(
          board,
          const MoveCard(
            opId: 'o',
            cardId: 'ghost',
            toColumnId: colB,
            baseVersion: 1,
          ),
        ),
        isFalse,
      );
      expect(
        canApplyOp(
          board,
          const MoveCard(
            opId: 'o',
            cardId: 'a1',
            toColumnId: 'ghost',
            baseVersion: 1,
          ),
        ),
        isFalse,
      );
      expect(
        canApplyOp(board, const ArchiveCard(opId: 'o', cardId: 'a1')),
        isTrue,
      );
      expect(
        canApplyOp(board, const ArchiveCard(opId: 'o', cardId: 'ghost')),
        isFalse,
      );
    });

    test('an archived card cannot be edited, moved or archived again', () {
      final archived = applyOp(
        board,
        const ArchiveCard(opId: 'o', cardId: 'a1'),
      );

      expect(
        canApplyOp(
          archived,
          const EditCardTitle(
            opId: 'o',
            cardId: 'a1',
            title: 't',
            actorId: 'u',
          ),
        ),
        isFalse,
      );
      expect(
        canApplyOp(
          archived,
          const EditCardDescription(
            opId: 'o',
            cardId: 'a1',
            description: 'd',
            baseDescriptionVersion: 1,
            actorId: 'u',
          ),
        ),
        isFalse,
      );
      expect(
        canApplyOp(archived, const ArchiveCard(opId: 'o', cardId: 'a1')),
        isFalse,
      );
    });

    test('create needs a free card id and an existing column', () {
      expect(
        canApplyOp(
          board,
          const CreateCard(
            opId: 'o',
            cardId: 'n',
            columnId: colA,
            title: 't',
            actorId: 'u',
          ),
        ),
        isTrue,
      );
      expect(
        canApplyOp(
          board,
          const CreateCard(
            opId: 'o',
            cardId: 'a1',
            columnId: colA,
            title: 't',
            actorId: 'u',
          ),
        ),
        isFalse,
      );
      expect(
        canApplyOp(
          board,
          const CreateCard(
            opId: 'o',
            cardId: 'n',
            columnId: 'ghost',
            title: 't',
            actorId: 'u',
          ),
        ),
        isFalse,
      );
    });

    test('column operations', () {
      expect(
        canApplyOp(
          board,
          const CreateColumn(opId: 'o', columnId: 'new', title: 't'),
        ),
        isTrue,
      );
      expect(
        canApplyOp(
          board,
          const CreateColumn(opId: 'o', columnId: colA, title: 't'),
        ),
        isFalse,
      );
      for (final op in <BoardOp>[
        const RenameColumn(opId: 'o', columnId: colA, title: 't'),
        const MoveColumn(opId: 'o', columnId: colA, baseVersion: 1),
        const ArchiveColumn(opId: 'o', columnId: colA),
      ]) {
        expect(canApplyOp(board, op), isTrue, reason: op.toString());
      }
      for (final op in <BoardOp>[
        const RenameColumn(opId: 'o', columnId: 'ghost', title: 't'),
        const MoveColumn(opId: 'o', columnId: 'ghost', baseVersion: 1),
        const ArchiveColumn(opId: 'o', columnId: 'ghost'),
      ]) {
        expect(canApplyOp(board, op), isFalse, reason: op.toString());
      }
    });
  });
}
