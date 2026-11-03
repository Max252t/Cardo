import 'package:cardo/core/realtime/connection_status.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/l10n/app_localizations_en.dart';
import 'package:cardo/l10n/app_localizations_ru.dart';
import 'package:cardo/features/board/presentation/widgets/board_snackbar.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/board_fixtures.dart';

final DateTime _t = DateTime.utc(2026, 1, 1);

const CreateColumn _createNew = CreateColumn(
  opId: 'cc',
  columnId: 'col-new',
  title: 'New',
  afterId: colC,
);

PendingOp _item(BoardOp op, {bool rejected = false}) {
  return PendingOp(
    op: op,
    status: rejected ? PendingOpStatus.rejected : PendingOpStatus.sent,
    createdAt: _t,
    rejection: rejected
        ? const OpRejection(reason: NackReason.forbidden)
        : null,
  );
}

BoardSyncState _state(List<PendingOp> pending) {
  return BoardSyncState(
    confirmed: makeBoard(),
    lastSeq: 10,
    pending: pending,
    connection: ConnectionStatus.connected,
  );
}

final List<BoardOp> _dependents = <BoardOp>[
  const CreateCard(
    opId: 'card',
    cardId: 'k1',
    columnId: 'col-new',
    title: 'T',
    actorId: 'u1',
  ),
  moveOp('a1', 'col-new', opId: 'move-card'),
  const RenameColumn(opId: 'rename', columnId: 'col-new', title: 'R'),
  const MoveColumn(opId: 'move', columnId: 'col-new', baseVersion: 1),
  const ArchiveColumn(opId: 'archive', columnId: 'col-new'),
  const CreateColumn(
    opId: 'after',
    columnId: 'col-next',
    title: 'Next',
    afterId: 'col-new',
  ),
];

void main() {
  group('referencesColumn', () {
    test('operations that name a column report it', () {
      for (final op in _dependents) {
        expect(op.referencesColumn('col-new'), isTrue, reason: '$op');
        expect(op.referencesColumn('other'), isFalse, reason: '$op');
      }
    });

    test('card operations inside other columns do not', () {
      expect(moveOp('a1', colB).referencesColumn('col-new'), isFalse);
      expect(
        const ArchiveCard(opId: 'x', cardId: 'a1').referencesColumn(colA),
        isFalse,
      );
    });
  });

  group('rejected CreateColumn', () {
    test('every dependent operation is held back', () {
      final state = _state(<PendingOp>[
        _item(_createNew, rejected: true),
        for (final op in _dependents) _item(op),
      ]);
      for (final op in _dependents) {
        expect(state.dependsOnRejectedColumnCreate(op), isTrue, reason: '$op');
      }
      expect(state.dependsOnRejectedColumnCreate(_createNew), isFalse);
      expect(state.dependsOnRejectedColumnCreate(moveOp('a1', colB)), isFalse);
    });

    test('operations on cards created in the column are held back too', () {
      const edit = EditCardTitle(
        opId: 'edit',
        cardId: 'k1',
        title: 'T2',
        actorId: 'u1',
      );
      const archive = ArchiveCard(opId: 'arch', cardId: 'k1');
      const description = EditCardDescription(
        opId: 'edit-d',
        cardId: 'k1',
        description: 'D',
        baseDescriptionVersion: 0,
        actorId: 'u1',
      );
      const foreign = ArchiveCard(opId: 'foreign', cardId: 'a1');
      final move = moveOp('k1', colB, opId: 'move-out');
      final state = _state(<PendingOp>[
        _item(_createNew, rejected: true),
        _item(_dependents.first),
        _item(edit),
        _item(archive),
        _item(description),
        _item(move),
        _item(foreign),
      ]);

      for (final op in <BoardOp>[edit, archive, description, move]) {
        expect(state.dependsOnRejectedColumnCreate(op), isTrue, reason: '$op');
      }
      expect(state.dependsOnRejectedColumnCreate(foreign), isFalse);
      expect(state.dependentOpIds(_createNew), <String>{
        'card',
        'edit',
        'arch',
        'edit-d',
        'move-out',
      });
    });

    test('dependents follow columns created after the rejected one', () {
      const rename = RenameColumn(opId: 'rn', columnId: 'col-next', title: 'R');
      final state = _state(<PendingOp>[
        _item(_createNew, rejected: true),
        _item(_dependents.last),
        _item(rename),
      ]);

      expect(state.dependsOnRejectedColumnCreate(rename), isTrue);
    });

    test('logging the rejection lists the edits of created cards', () {
      final state = _state(<PendingOp>[
        _item(_createNew, rejected: true),
        _item(_dependents.first),
        _item(
          const EditCardTitle(
            opId: 'edit',
            cardId: 'k1',
            title: 'T2',
            actorId: 'u1',
          ),
        ),
      ]).withRejectionLogged('cc');

      expect(state.rejections.entries.length, 3);
    });

    test('stale CreateColumn drops the edits of cards created in it', () {
      final old = DateTime.utc(2025, 1, 1);
      final state = _state(<PendingOp>[
        PendingOp(
          op: _createNew,
          status: PendingOpStatus.queued,
          createdAt: old,
        ),
        _item(_dependents.first),
        _item(
          const EditCardTitle(
            opId: 'edit',
            cardId: 'k1',
            title: 'T2',
            actorId: 'u1',
          ),
        ),
      ]).withoutStale(_t, const Duration(hours: 1));

      expect(state.pending, isEmpty);
    });

    test('an accepted CreateColumn holds nothing back', () {
      final state = _state(<PendingOp>[
        _item(_createNew),
        ..._dependents.map(_item),
      ]);
      for (final op in _dependents) {
        expect(state.dependsOnRejectedColumnCreate(op), isFalse);
      }
    });

    test('logging the rejection lists the dropped dependents', () {
      final state = _state(<PendingOp>[
        _item(_createNew, rejected: true),
        for (final op in _dependents) _item(op),
        _item(moveOp('a1', colB, opId: 'unrelated')),
      ]).withRejectionLogged('cc');

      final kinds = state.rejections.entries.map((entry) => entry.kind);
      expect(kinds.first, RejectedOpKind.createColumn);
      expect(kinds.length, 1 + _dependents.length);
      expect(
        state.rejections.entries
            .skip(1)
            .every((entry) => entry.dropCause == DropCause.targetGone),
        isTrue,
      );
    });
  });

  group('stale CreateColumn', () {
    test('drops the operations that depend on it with the log', () {
      final old = PendingOp(
        op: _createNew,
        status: PendingOpStatus.queued,
        createdAt: _t,
      );
      final dependent = PendingOp(
        op: const RenameColumn(opId: 'rename', columnId: 'col-new', title: 'R'),
        status: PendingOpStatus.queued,
        createdAt: _t.add(const Duration(minutes: 9)),
      );
      final fresh = PendingOp(
        op: moveOp('a1', colB, opId: 'fresh'),
        status: PendingOpStatus.queued,
        createdAt: _t.add(const Duration(minutes: 9)),
      );
      final state = _state(<PendingOp>[old, dependent, fresh]).withoutStale(
        _t.add(const Duration(minutes: 10)),
        const Duration(minutes: 5),
      );

      expect(state.pending.map((item) => item.opId), <String>['fresh']);
      final kinds = state.rejections.entries.map((entry) => entry.kind).toSet();
      expect(kinds, <RejectedOpKind>{
        RejectedOpKind.createColumn,
        RejectedOpKind.renameColumn,
      });
    });
  });

  group('column nack texts', () {
    test('version conflict on a column move without and with an author', () {
      final ru = AppLocalizationsRu();
      final en = AppLocalizationsEn();
      const conflict = OpRejection(reason: NackReason.versionConflict);
      expect(
        nackMessage(ru, conflict, actorName: null, column: true),
        'Колонку уже переместил другой участник.',
      );
      expect(
        nackMessage(ru, conflict, actorName: 'Максим', column: true),
        'Колонку уже переместил Максим.',
      );
      expect(
        nackMessage(en, conflict, actorName: null, column: true),
        'Another member already moved this column.',
      );
      expect(
        nackMessage(en, conflict, actorName: 'Max', column: true),
        'Max already moved this column.',
      );
    });

    test('not found on a column and unchanged card texts', () {
      final ru = AppLocalizationsRu();
      const missing = OpRejection(reason: NackReason.notFound);
      expect(
        nackMessage(ru, missing, actorName: null, column: true),
        'Колонка уже в архиве.',
      );
      expect(
        nackMessage(ru, missing, actorName: null),
        'Карточка уже в архиве.',
      );
      expect(
        nackMessage(
          ru,
          const OpRejection(reason: NackReason.versionConflict),
          actorName: null,
        ),
        'Карточку уже изменил другой участник.',
      );
    });
  });
}
