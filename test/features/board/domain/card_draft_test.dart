import 'package:cardo/core/realtime/connection_status.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/domain/apply_op.dart';
import 'package:cardo/features/board/domain/board_model.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/domain/card_draft.dart';
import 'package:flutter_test/flutter_test.dart';

const String _card = DemoIds.handshakeCard;

BoardSyncState _state({
  BoardModel? confirmed,
  List<PendingOp> pending = const <PendingOp>[],
}) {
  return BoardSyncState(
    confirmed: confirmed ?? demoBoard(),
    lastSeq: 1284,
    pending: pending,
    connection: ConnectionStatus.connected,
  );
}

BoardModel _withCard(CardModel Function(CardModel card) change) {
  final board = demoBoard();
  final card = board.cardById(_card)!;
  return board.copyWith(
    cards: <CardModel>[
      for (final other in board.cards) other.id == _card ? change(card) : other,
    ],
  );
}

CardDraft _draft({
  String text = 'draft',
  int base = 1,
  String? opId,
  bool conflict = false,
  String? actor,
}) {
  return CardDraft(
    cardId: _card,
    text: text,
    baseDescriptionVersion: base,
    submittedOpId: opId,
    conflict: conflict,
    conflictActorId: actor,
  );
}

EditCardDescription _op(String opId, String text, {int base = 1}) {
  return EditCardDescription(
    opId: opId,
    cardId: _card,
    description: text,
    baseDescriptionVersion: base,
    actorId: DemoIds.elena,
  );
}

PendingOp _pending(
  String opId,
  String text, {
  PendingOpStatus status = PendingOpStatus.sent,
  OpRejection? rejection,
}) {
  return PendingOp(
    op: _op(opId, text),
    status: status,
    createdAt: DateTime.utc(2026),
    rejection: rejection,
  );
}

void main() {
  group('unsubmitted draft', () {
    test('stays untouched while the version has not grown', () {
      final draft = _draft();
      expect(identical(reconcileDraft(draft, _state()), draft), isTrue);
    });

    test('conflict when the version grew and the text differs', () {
      final confirmed = _withCard(
        (card) => card.copyWith(
          description: 'remote',
          descriptionVersion: 2,
          updatedBy: DemoIds.maxim,
        ),
      );
      final result = reconcileDraft(_draft(), _state(confirmed: confirmed))!;
      expect(result.conflict, isTrue);
      expect(result.conflictActorId, DemoIds.maxim);
      expect(result.text, 'draft');
      expect(result.baseDescriptionVersion, 1);
    });

    test('no conflict and no draft when the remote text equals ours', () {
      final confirmed = _withCard(
        (card) => card.copyWith(description: 'draft', descriptionVersion: 2),
      );
      expect(reconcileDraft(_draft(), _state(confirmed: confirmed)), isNull);
    });

    test('an existing conflict is kept as is', () {
      final confirmed = _withCard(
        (card) => card.copyWith(description: 'remote', descriptionVersion: 3),
      );
      final draft = _draft(conflict: true, actor: DemoIds.anya);
      expect(
        identical(reconcileDraft(draft, _state(confirmed: confirmed)), draft),
        isTrue,
      );
    });

    test('missing card drops the draft', () {
      final board = demoBoard();
      final confirmed = board.copyWith(
        cards: board.cards.where((card) => card.id != _card).toList(),
      );
      expect(reconcileDraft(_draft(), _state(confirmed: confirmed)), isNull);
    });

    test('archived card drops the draft', () {
      final confirmed = _withCard((card) => card.copyWith(archived: true));
      expect(reconcileDraft(_draft(), _state(confirmed: confirmed)), isNull);
      expect(
        reconcileDraft(
          _draft(opId: 'op'),
          _state(confirmed: confirmed, pending: [_pending('op', 'draft')]),
        ),
        isNull,
      );
    });
  });

  group('submitted draft', () {
    test('stays while the op is in flight', () {
      final draft = _draft(opId: 'op');
      final state = _state(pending: [_pending('op', 'draft')]);
      expect(identical(reconcileDraft(draft, state), draft), isTrue);
    });

    test('version_conflict nack turns into a conflict with the actor', () {
      final state = _state(
        pending: [
          _pending(
            'op',
            'draft',
            status: PendingOpStatus.rejected,
            rejection: const OpRejection(
              reason: NackReason.versionConflict,
              actorId: DemoIds.maxim,
            ),
          ),
        ],
      );
      final result = reconcileDraft(_draft(opId: 'op'), state)!;
      expect(result.conflict, isTrue);
      expect(result.conflictActorId, DemoIds.maxim);
      expect(result.submitted, isFalse);
      expect(result.text, 'draft');
    });

    test('version_conflict nack without actor still conflicts', () {
      final state = _state(
        pending: [
          _pending(
            'op',
            'draft',
            status: PendingOpStatus.rejected,
            rejection: const OpRejection(reason: NackReason.versionConflict),
          ),
        ],
      );
      final result = reconcileDraft(_draft(opId: 'op'), state)!;
      expect(result.conflict, isTrue);
      expect(result.conflictActorId, isNull);
    });

    test('other nack reasons return the draft to unsubmitted', () {
      for (final reason in <NackReason>[
        NackReason.forbidden,
        NackReason.notFound,
        NackReason.validationError,
        NackReason.rateLimited,
        NackReason.internal,
      ]) {
        final state = _state(
          pending: [
            _pending(
              'op',
              'draft',
              status: PendingOpStatus.rejected,
              rejection: OpRejection(reason: reason),
            ),
          ],
        );
        final result = reconcileDraft(_draft(opId: 'op'), state)!;
        expect(result.submitted, isFalse, reason: reason.name);
        expect(result.conflict, isFalse, reason: reason.name);
        expect(result.text, 'draft');
      }
    });

    test('confirmation of our op removes the draft', () {
      final confirmed = applyOp(demoBoard(), _op('op', 'draft'));
      expect(
        reconcileDraft(_draft(opId: 'op'), _state(confirmed: confirmed)),
        isNull,
      );
    });

    test('typing after submit rebases onto the confirmed version', () {
      final confirmed = applyOp(demoBoard(), _op('op', 'draft'));
      final result = reconcileDraft(
        _draft(text: 'draft and more', opId: 'op'),
        _state(confirmed: confirmed),
      )!;
      expect(result.submitted, isFalse);
      expect(result.conflict, isFalse);
      expect(result.text, 'draft and more');
      expect(
        result.baseDescriptionVersion,
        confirmed.cardById(_card)!.descriptionVersion,
      );
      expect(result.baseDescriptionVersion, 2);
    });

    test('a rebased draft is not a conflict on the next reconcile', () {
      final confirmed = applyOp(demoBoard(), _op('op', 'draft'));
      final rebased = reconcileDraft(
        _draft(text: 'draft and more', opId: 'op'),
        _state(confirmed: confirmed),
      )!;
      expect(
        identical(
          reconcileDraft(rebased, _state(confirmed: confirmed)),
          rebased,
        ),
        isTrue,
      );
    });
  });

  group('reconcileDrafts', () {
    test('keeps survivors and drops the rest', () {
      final confirmed = _withCard((card) => card.copyWith(archived: true));
      const other = CardDraft(
        cardId: DemoIds.rankCard,
        text: 'x',
        baseDescriptionVersion: 1,
      );
      final result = reconcileDrafts(<String, CardDraft>{
        _card: _draft(),
        DemoIds.rankCard: other,
      }, _state(confirmed: confirmed));
      expect(result.keys, <String>[DemoIds.rankCard]);
      expect(result[DemoIds.rankCard], other);
    });
  });

  group('descriptionOpFor', () {
    final at = DateTime.utc(2026, 1, 2);

    test('builds an operation from the draft', () {
      final op = descriptionOpFor(
        _draft(base: 4),
        opId: 'id',
        actorId: 'u',
        at: at,
      );
      expect(op, isNotNull);
      expect(op!.description, 'draft');
      expect(op.baseDescriptionVersion, 4);
      expect(op.actorId, 'u');
      expect(op.at, at);
    });

    test('refuses conflicted, submitted and oversized drafts', () {
      expect(
        descriptionOpFor(
          _draft(conflict: true),
          opId: 'id',
          actorId: 'u',
          at: at,
        ),
        isNull,
      );
      expect(
        descriptionOpFor(
          _draft(opId: 'o'),
          opId: 'id',
          actorId: 'u',
          at: at,
        ),
        isNull,
      );
      expect(
        descriptionOpFor(
          _draft(text: 'x' * 10001),
          opId: 'id',
          actorId: 'u',
          at: at,
        ),
        isNull,
      );
      expect(
        descriptionOpFor(
          _draft(text: 'x' * 10000),
          opId: 'id',
          actorId: 'u',
          at: at,
        ),
        isNotNull,
      );
    });
  });

  group('CardDraft transitions', () {
    test('tooLong boundary', () {
      expect(_draft(text: 'x' * 10000).tooLong, isFalse);
      expect(_draft(text: 'x' * 10001).tooLong, isTrue);
    });

    test('submittedAs clears the conflict, conflictedBy clears the submit', () {
      final conflicted = _draft().conflictedBy('u');
      expect(conflicted.submittedAs('o').conflict, isFalse);
      expect(conflicted.submittedAs('o').submittedOpId, 'o');
      expect(_draft(opId: 'o').conflictedBy('u').submitted, isFalse);
    });

    test('withText keeps flags, rebased resets them', () {
      final conflicted = _draft(conflict: true, actor: 'u');
      expect(conflicted.withText('z').conflict, isTrue);
      expect(conflicted.withText('z').conflictActorId, 'u');
      final rebased = conflicted.rebased(7);
      expect(rebased.conflict, isFalse);
      expect(rebased.baseDescriptionVersion, 7);
    });
  });
}
