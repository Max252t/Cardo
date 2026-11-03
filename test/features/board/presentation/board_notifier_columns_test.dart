import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/data/fake_board_gateway.dart';
import 'package:cardo/features/board/domain/board_model.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/board_fixtures.dart';

const Duration _tick = Duration(milliseconds: 1);
const Duration _hold = Duration(milliseconds: 100);

const BoardSyncConfig _config = BoardSyncConfig(
  nackHold: _hold,
  retryDelay: Duration(milliseconds: 50),
  maxInternalRetries: 2,
);

BoardSyncState _read(ProviderContainer container) =>
    container.read(boardNotifierProvider);

FakeBoardGateway _fake({RejectPolicy? rejectWhen, BoardRole? role}) {
  return FakeBoardGateway(
    initial: demoBoardSnapshot(currentUserRole: role ?? BoardRole.editor),
    confirmDelay: Duration.zero,
    rejectWhen: rejectWhen,
  );
}

Future<ProviderContainer> _open(
  WidgetTester tester, {
  FakeBoardGateway? gateway,
  BoardRole role = BoardRole.editor,
}) async {
  final container = makeContainer(
    gateway: gateway ?? _fake(role: role),
    config: _config,
  );
  container.listen<BoardSyncState>(boardNotifierProvider, (_, _) {});
  await tester.pump(_tick);
  return container;
}

List<String> _titles(BoardModel board) => [
  for (final column in board.orderedColumns) column.title,
];

void main() {
  group('createColumn', () {
    testWidgets('appends a trimmed column that is visible at once', (
      tester,
    ) async {
      final container = await _open(tester);
      final notifier = container.read(boardNotifierProvider.notifier);

      final id = notifier.createColumn('  Идеи  ');

      final state = _read(container);
      final op = state.pending.single.op as CreateColumn;
      expect(id, op.columnId);
      expect(op.title, 'Идеи');
      expect(op.afterId, DemoIds.done);
      expect(op.beforeId, isNull);
      expect(_titles(state.liveView).last, 'Идеи');
      expect(_titles(state.confirmed), isNot(contains('Идеи')));

      await tester.pump(_tick);
      final done = _read(container);
      expect(done.pending, isEmpty);
      expect(_titles(done.confirmed).last, 'Идеи');
      await _close(tester, container);
    });

    testWidgets('markers follow the position and match the server result', (
      tester,
    ) async {
      final container = await _open(tester);
      final notifier = container.read(boardNotifierProvider.notifier);
      ColumnMarker markerOf(BoardModel board, String id) =>
          board.columnById(id)!.marker;
      final before = _read(container).liveView;
      expect(markerOf(before, DemoIds.review), ColumnMarker.review);
      expect(markerOf(before, DemoIds.done), ColumnMarker.done);

      final id = notifier.createColumn('Идеи')!;

      final optimistic = _read(container).liveView;
      expect(markerOf(optimistic, DemoIds.backlog), ColumnMarker.backlog);
      expect(markerOf(optimistic, DemoIds.inProgress), ColumnMarker.inProgress);
      expect(markerOf(optimistic, DemoIds.review), ColumnMarker.review);
      expect(markerOf(optimistic, DemoIds.done), ColumnMarker.review);
      expect(markerOf(optimistic, id), ColumnMarker.done);

      await tester.pump(_tick);
      final confirmed = _read(container).confirmed;
      expect(
        [for (final column in confirmed.orderedColumns) column.marker],
        [for (final column in optimistic.orderedColumns) column.marker],
      );
      await _close(tester, container);
    });

    testWidgets('rejects empty, blank and over-long names', (tester) async {
      final container = await _open(tester);
      final notifier = container.read(boardNotifierProvider.notifier);

      expect(notifier.createColumn(''), isNull);
      expect(notifier.createColumn('   '), isNull);
      expect(notifier.createColumn('я' * 201), isNull);
      expect(_read(container).pending, isEmpty);

      expect(notifier.createColumn('я' * 200), isNotNull);
      expect(_read(container).pending.length, 1);
      await _close(tester, container);
    });

    testWidgets('a viewer cannot create, rename, move or archive', (
      tester,
    ) async {
      final container = await _open(tester, role: BoardRole.viewer);
      final notifier = container.read(boardNotifierProvider.notifier);

      expect(notifier.createColumn('Идеи'), isNull);
      notifier.renameColumn(columnId: DemoIds.review, title: 'Другое');
      notifier.moveColumn(columnId: DemoIds.review, direction: 1);
      notifier.archiveColumn(DemoIds.review);

      expect(_read(container).pending, isEmpty);
      await _close(tester, container);
    });
  });

  group('renameColumn', () {
    testWidgets('sends the trimmed title and skips no-ops', (tester) async {
      final container = await _open(tester);
      final notifier = container.read(boardNotifierProvider.notifier);

      notifier.renameColumn(columnId: DemoIds.review, title: 'Ревью');
      notifier.renameColumn(columnId: DemoIds.review, title: '   ');
      notifier.renameColumn(columnId: 'missing', title: 'X');
      expect(_read(container).pending, isEmpty);

      notifier.renameColumn(columnId: DemoIds.review, title: '  QA  ');
      final op = _read(container).pending.single.op as RenameColumn;
      expect(op.title, 'QA');
      expect(_titles(_read(container).liveView), contains('QA'));

      await tester.pump(_tick);
      expect(_titles(_read(container).confirmed), contains('QA'));
      await _close(tester, container);
    });
  });

  group('moveColumn', () {
    testWidgets('moves right with neighbour anchors and the base version', (
      tester,
    ) async {
      final container = await _open(tester);
      final notifier = container.read(boardNotifierProvider.notifier);
      final version = _read(container).confirmed.columnById(DemoIds.review)!;

      notifier.moveColumn(columnId: DemoIds.review, direction: 1);

      final op = _read(container).pending.single.op as MoveColumn;
      expect(op.columnId, DemoIds.review);
      expect(op.baseVersion, version.version);
      expect(op.afterId, DemoIds.done);
      expect(op.beforeId, isNull);
      expect(_titles(_read(container).liveView), [
        'Бэклог',
        'В работе',
        'Готово',
        'Ревью',
      ]);

      await tester.pump(_tick);
      final done = _read(container);
      expect(done.pending, isEmpty);
      expect(_titles(done.confirmed), _titles(done.liveView));
      expect(done.confirmed.columnById(DemoIds.review)!.version, 2);
      await _close(tester, container);
    });

    testWidgets('moves left between its new neighbours', (tester) async {
      final container = await _open(tester);
      final notifier = container.read(boardNotifierProvider.notifier);

      notifier.moveColumn(columnId: DemoIds.review, direction: -1);

      final op = _read(container).pending.single.op as MoveColumn;
      expect(op.afterId, DemoIds.backlog);
      expect(op.beforeId, DemoIds.inProgress);
      expect(_titles(_read(container).liveView), [
        'Бэклог',
        'Ревью',
        'В работе',
        'Готово',
      ]);
      await _close(tester, container);
    });

    testWidgets('moving the first column to the front or the last to the end '
        'is ignored', (tester) async {
      final container = await _open(tester);
      final notifier = container.read(boardNotifierProvider.notifier);

      notifier.moveColumn(columnId: DemoIds.backlog, direction: -1);
      notifier.moveColumn(columnId: DemoIds.done, direction: 1);
      notifier.moveColumn(columnId: DemoIds.done, direction: 0);

      expect(_read(container).pending, isEmpty);
      await _close(tester, container);
    });

    testWidgets(
      'a version conflict is kept as a rejection of the column move',
      (tester) async {
        final container = await _open(
          tester,
          gateway: _fake(
            rejectWhen: (op) => op is MoveColumn
                ? const OpRejection(reason: NackReason.versionConflict)
                : null,
          ),
        );
        final notifier = container.read(boardNotifierProvider.notifier);

        notifier.moveColumn(columnId: DemoIds.review, direction: 1);
        await tester.pump(_tick);

        final state = _read(container);
        expect(state.pending.single.isRejected, isTrue);
        expect(
          state.pending.single.rejection!.reason,
          NackReason.versionConflict,
        );
        expect(_titles(state.liveView).last, 'Готово');
        expect(state.rejections.entries.single.kind, RejectedOpKind.moveColumn);
        await tester.pump(_hold * 2);
        expect(_read(container).pending, isEmpty);
        await _close(tester, container);
      },
    );
  });

  group('archiveColumn', () {
    testWidgets('removes the column and its cards from the view', (
      tester,
    ) async {
      final container = await _open(tester);
      final notifier = container.read(boardNotifierProvider.notifier);
      final inside = _read(container).liveView.cardsIn(DemoIds.review);
      expect(inside, isNotEmpty);

      notifier.archiveColumn(DemoIds.review);

      final view = _read(container).liveView;
      expect(view.columnById(DemoIds.review), isNull);
      for (final card in inside) {
        expect(view.activeCard(card.id), isNull);
      }
      expect(view.orderedColumns.length, 3);
      expect(view.columnById(DemoIds.done)!.marker, ColumnMarker.done);

      await tester.pump(_tick);
      expect(_read(container).pending, isEmpty);
      expect(_read(container).confirmed.columnById(DemoIds.review), isNull);
      await _close(tester, container);
    });

    testWidgets('an unknown column is ignored', (tester) async {
      final container = await _open(tester);
      container.read(boardNotifierProvider.notifier).archiveColumn('missing');
      expect(_read(container).pending, isEmpty);
      await _close(tester, container);
    });
  });

  group('column then card chain', () {
    testWidgets('edit, move and archive reach the server in order', (
      tester,
    ) async {
      final gateway = FakeBoardGateway(
        initial: demoBoardSnapshot(),
        confirmDelay: const Duration(milliseconds: 20),
      );
      final container = await _open(tester, gateway: gateway);
      final notifier = container.read(boardNotifierProvider.notifier);
      final columnId = notifier.createColumn('Идеи')!;
      notifier.createCard(columnId: columnId, title: 'Первая');
      final cardId = _read(container).liveView.cardsIn(columnId).single.id;
      notifier.editCardTitle(cardId: cardId, title: 'Вторая');
      notifier.moveCard(cardId: cardId, toColumnId: DemoIds.review);
      notifier.archiveCard(cardId);

      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }

      final state = _read(container);
      expect(state.rejections.entries, isEmpty);
      expect(state.pending, isEmpty);
      expect(gateway.serverBoard.activeCard(cardId), isNull);
      await _close(tester, container);
    });

    testWidgets('a title edit lands on the new card', (tester) async {
      final gateway = FakeBoardGateway(
        initial: demoBoardSnapshot(),
        confirmDelay: const Duration(milliseconds: 20),
      );
      final container = await _open(tester, gateway: gateway);
      final notifier = container.read(boardNotifierProvider.notifier);
      final columnId = notifier.createColumn('Идеи')!;
      notifier.createCard(columnId: columnId, title: 'Первая');
      final cardId = _read(container).liveView.cardsIn(columnId).single.id;
      notifier.editCardTitle(cardId: cardId, title: 'Вторая');

      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }

      expect(_read(container).rejections.entries, isEmpty);
      expect(gateway.serverBoard.cardById(cardId)?.title, 'Вторая');
      await _close(tester, container);
    });
  });

  group('rejected CreateColumn', () {
    testWidgets('drops the operations that depend on the new column', (
      tester,
    ) async {
      final gateway = _fake(
        rejectWhen: (op) => op is CreateColumn
            ? const OpRejection(reason: NackReason.forbidden)
            : null,
      );
      final container = await _open(tester, gateway: gateway);
      final notifier = container.read(boardNotifierProvider.notifier);
      final columnId = notifier.createColumn('Идеи')!;
      notifier.createCard(columnId: columnId, title: 'Первая');
      notifier.renameColumn(columnId: columnId, title: 'Идеи 2');
      notifier.archiveColumn(columnId);
      expect(_read(container).pending.length, 4);

      await tester.pump(_tick);

      final held = _read(container);
      expect(held.pending.where((item) => item.isRejected).length, 1);
      expect(held.hasRejectedCreate('none'), isFalse);
      expect(
        held.rejections.entries.map((entry) => entry.kind),
        containsAll(<RejectedOpKind>[
          RejectedOpKind.createColumn,
          RejectedOpKind.create,
          RejectedOpKind.renameColumn,
          RejectedOpKind.archiveColumn,
        ]),
      );
      expect(
        gateway.serverBoard.cards.where((card) => card.title == 'Первая'),
        isEmpty,
      );

      await tester.pump(_hold * 2);
      expect(_read(container).pending, isEmpty);
      expect(_read(container).liveView.columnById(columnId), isNull);
      await _close(tester, container);
    });

    testWidgets('edits and moves of the new card are dropped without a '
        'second nack', (tester) async {
      var nacks = 0;
      final gateway = FakeBoardGateway(
        initial: demoBoardSnapshot(),
        confirmDelay: const Duration(milliseconds: 20),
        rejectWhen: (op) {
          if (op is CreateColumn) {
            return const OpRejection(reason: NackReason.forbidden);
          }
          nacks++;
          return null;
        },
      );
      final container = await _open(tester, gateway: gateway);
      final notifier = container.read(boardNotifierProvider.notifier);
      final columnId = notifier.createColumn('Идеи')!;
      notifier.createCard(columnId: columnId, title: 'Первая');
      final cardId = _read(container).liveView.cardsIn(columnId).single.id;
      notifier.editCardTitle(cardId: cardId, title: 'Вторая');
      notifier.moveCard(cardId: cardId, toColumnId: DemoIds.review);

      await tester.pump(const Duration(milliseconds: 30));
      await tester.pump(const Duration(milliseconds: 30));

      final held = _read(container);
      expect(held.pending.where((item) => item.isRejected).length, 1);
      expect(
        held.rejections.entries.map((entry) => entry.kind),
        containsAll(<RejectedOpKind>[
          RejectedOpKind.createColumn,
          RejectedOpKind.create,
        ]),
      );
      expect(nacks, 0);
      expect(gateway.serverBoard.cardById(cardId), isNull);

      await tester.pump(_hold * 2);
      expect(_read(container).pending, isEmpty);
      expect(_read(container).liveView.cardById(cardId), isNull);
      await _close(tester, container);
    });

    testWidgets('operations on other columns are not affected', (tester) async {
      final gateway = _fake(
        rejectWhen: (op) => op is CreateColumn
            ? const OpRejection(reason: NackReason.forbidden)
            : null,
      );
      final container = await _open(tester, gateway: gateway);
      final notifier = container.read(boardNotifierProvider.notifier);
      notifier.createColumn('Идеи');
      notifier.createCard(columnId: DemoIds.review, title: 'Живая');

      await tester.pump(_tick);
      await tester.pump(_hold * 2);

      expect(_read(container).pending, isEmpty);
      expect(
        _read(container).confirmed.cardsIn(DemoIds.review).map((c) => c.title),
        contains('Живая'),
      );
      await _close(tester, container);
    });
  });
}

Future<void> _close(WidgetTester tester, ProviderContainer container) async {
  await tester.pump(const Duration(milliseconds: 200));
  container.dispose();
}
