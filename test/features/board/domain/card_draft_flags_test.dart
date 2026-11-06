import 'package:cardo/core/realtime/connection_status.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/domain/board_model.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/domain/card_draft.dart';
import 'package:flutter_test/flutter_test.dart';

const String _card = DemoIds.handshakeCard;

BoardSyncState _state({
  BoardModel? confirmed,
  List<PendingOp> pending = const <PendingOp>[],
  int lastSeq = 1284,
}) {
  return BoardSyncState(
    confirmed: confirmed ?? demoBoard(),
    lastSeq: lastSeq,
    pending: pending,
    connection: ConnectionStatus.connected,
  );
}

CardDraft _draft({
  String text = 'draft',
  int base = 1,
  String? opId,
  bool conflict = false,
  int? atSeq,
  bool flush = false,
}) {
  return CardDraft(
    cardId: _card,
    text: text,
    baseDescriptionVersion: base,
    submittedOpId: opId,
    conflict: conflict,
    conflictAtSeq: atSeq,
    flushRequested: flush,
  );
}

PendingOp _pending(
  BoardOp op, {
  PendingOpStatus status = PendingOpStatus.sent,
  OpRejection? rejection,
}) {
  return PendingOp(
    op: op,
    status: status,
    createdAt: DateTime.utc(2026),
    rejection: rejection,
  );
}

BoardModel _withRemote(String text, int version) {
  final board = demoBoard();
  return board.copyWith(
    cards: <CardModel>[
      for (final card in board.cards)
        card.id == _card
            ? card.copyWith(
                description: text,
                descriptionVersion: version,
                updatedBy: DemoIds.maxim,
              )
            : card,
    ],
  );
}

void main() {
  group('submitted draft whose operation disappeared', () {
    test('rebases onto the version created by the own operation', () {
      final next = reconcileDraft(_draft(opId: 'a', text: 'mine'), _state())!;
      expect(next.submitted, isFalse);
      expect(next.baseDescriptionVersion, 2);
      expect(next.conflict, isFalse);
      expect(next.text, 'mine');
    });

    test('raises a conflict when a newer remote version is already there', () {
      final state = _state(confirmed: _withRemote('theirs', 3));
      final next = reconcileDraft(_draft(opId: 'a', text: 'mine'), state)!;
      expect(next.conflict, isTrue);
      expect(next.conflictActorId, DemoIds.maxim);
      expect(next.baseDescriptionVersion, 2);
      expect(next.text, 'mine');
    });

    test('is removed when the confirmed text equals the draft', () {
      final state = _state(confirmed: _withRemote('mine', 2));
      expect(reconcileDraft(_draft(opId: 'a', text: 'mine'), state), isNull);
    });
  });

  group('card that is not confirmed yet', () {
    const create = CreateCard(
      opId: 'c',
      cardId: 'new-card',
      columnId: DemoIds.backlog,
      title: 'New',
      actorId: DemoIds.elena,
    );
    CardDraft draftFor(String id) =>
        CardDraft(cardId: id, text: 'x', baseDescriptionVersion: 1);

    test('survives while the create is pending', () {
      final state = _state(pending: [_pending(create)]);
      final draft = draftFor('new-card');
      expect(identical(reconcileDraft(draft, state), draft), isTrue);
      expect(isDraftBlocked(draft, state), isTrue);
    });

    test('is dropped when the create is rejected', () {
      final state = _state(
        pending: [
          _pending(
            create,
            status: PendingOpStatus.rejected,
            rejection: const OpRejection(reason: NackReason.forbidden),
          ),
        ],
      );
      expect(reconcileDraft(draftFor('new-card'), state), isNull);
    });

    test('is dropped for an unknown card', () {
      expect(reconcileDraft(draftFor('nope'), _state()), isNull);
    });
  });

  group('blocking', () {
    const move = MoveCard(
      opId: 'm',
      cardId: _card,
      toColumnId: DemoIds.done,
      baseVersion: 1,
    );
    const edit = EditCardDescription(
      opId: 'e',
      cardId: _card,
      description: 'x',
      baseDescriptionVersion: 1,
      actorId: DemoIds.elena,
    );

    test('a rejected move blocks the draft', () {
      final state = _state(
        pending: [
          _pending(
            move,
            status: PendingOpStatus.rejected,
            rejection: const OpRejection(reason: NackReason.forbidden),
          ),
        ],
      );
      expect(state.hasBlockingRejection(_card), isTrue);
      expect(state.blockingRejection(_card)!.reason, NackReason.forbidden);
      expect(isDraftBlocked(_draft(), state), isTrue);
    });

    test('a description conflict does not block', () {
      final state = _state(
        pending: [
          _pending(
            edit,
            status: PendingOpStatus.rejected,
            rejection: const OpRejection(reason: NackReason.versionConflict),
          ),
        ],
      );
      expect(state.hasBlockingRejection(_card), isFalse);
      expect(state.blockingRejection(_card), isNull);
      expect(isDraftBlocked(_draft(), state), isFalse);
    });

    test('a pending operation does not block', () {
      final state = _state(pending: [_pending(move)]);
      expect(state.hasBlockingRejection(_card), isFalse);
    });
  });

  group('conflict resolvability', () {
    test('a draft without a conflict is always resolvable', () {
      expect(isConflictResolvable(_draft(), _state()), isTrue);
    });

    test('waits for the sequence announced by the nack', () {
      final draft = _draft(conflict: true, atSeq: 1290);
      expect(isConflictResolvable(draft, _state(lastSeq: 1289)), isFalse);
      expect(isConflictResolvable(draft, _state(lastSeq: 1290)), isTrue);
    });

    test('a newer confirmed description version is enough', () {
      final draft = _draft(conflict: true, atSeq: 1290);
      final state = _state(confirmed: _withRemote('theirs', 2));
      expect(isConflictResolvable(draft, state), isTrue);
    });

    test('a missing sequence is resolvable', () {
      expect(isConflictResolvable(_draft(conflict: true), _state()), isTrue);
    });

    test('a rejection carries its sequence into the draft', () {
      const edit = EditCardDescription(
        opId: 'e',
        cardId: _card,
        description: 'mine',
        baseDescriptionVersion: 1,
        actorId: DemoIds.elena,
      );
      final state = _state(
        pending: [
          _pending(
            edit,
            status: PendingOpStatus.rejected,
            rejection: const OpRejection(
              reason: NackReason.versionConflict,
              actorId: DemoIds.maxim,
              atSeq: 1290,
            ),
          ),
        ],
      );
      final next = reconcileDraft(_draft(opId: 'e', text: 'mine'), state)!;
      expect(next.conflict, isTrue);
      expect(next.conflictAtSeq, 1290);
      expect(next.conflictActorId, DemoIds.maxim);
    });
  });

  group('flush flag', () {
    test('typing clears it, submitting clears it, equality sees it', () {
      final flagged = _draft().withFlushRequested();
      expect(flagged.flushRequested, isTrue);
      expect(flagged == _draft(), isFalse);
      expect(flagged.hashCode == _draft().hashCode, isFalse);
      expect(flagged.withText('more').flushRequested, isFalse);
      expect(flagged.submittedAs('o').flushRequested, isFalse);
      expect(flagged.unsubmitted().flushRequested, isTrue);
      expect(flagged.rebased(2).flushRequested, isTrue);
    });
  });
}
