import 'package:cardo/core/realtime/scheduler.dart';
import 'package:cardo/features/board/data/board_gateway.dart';
import 'package:cardo/features/board/data/op_sender.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/engine_rig.dart';

const CreateColumn _createCol = CreateColumn(
  opId: 'cc',
  columnId: 'col-new',
  title: 'New',
);

const CreateColumn _createNext = CreateColumn(
  opId: 'cc2',
  columnId: 'col-next',
  title: 'Next',
  afterId: 'col-new',
);

const CreateCard _createCard = CreateCard(
  opId: 'ck',
  cardId: 'k1',
  columnId: 'col-new',
  title: 'T',
  actorId: 'u1',
);

const EditCardTitle _edit = EditCardTitle(
  opId: 'edit',
  cardId: 'k1',
  title: 'T2',
  actorId: 'u1',
);

const EditCardDescription _editDescription = EditCardDescription(
  opId: 'edit-d',
  cardId: 'k1',
  description: 'D',
  baseDescriptionVersion: 0,
  actorId: 'u1',
);

const ArchiveCard _archive = ArchiveCard(opId: 'arch', cardId: 'k1');

const MoveCard _move = MoveCard(
  opId: 'move',
  cardId: 'k1',
  toColumnId: 'col-old',
  baseVersion: 1,
);

OpSender _sender(List<String> sent, {Scheduler? scheduler, int burst = 10}) {
  return OpSender(
    scheduler: scheduler ?? RecordingScheduler(),
    now: DateTime.now,
    dispatch: (op) {
      sent.add(op.opId);
      return SendOutcome.sent;
    },
    shouldSend: (_) => true,
    onStall: (_) {},
    burst: burst,
  );
}

void main() {
  group('column barrier', () {
    test('card operations wait behind the create blocked by the column', () {
      final sent = <String>[];
      final sender = _sender(sent);

      sender.enqueue(_createCol);
      sender.enqueue(_createCard);
      sender.enqueue(_edit);
      sender.enqueue(_editDescription);
      sender.enqueue(_move);
      sender.enqueue(_archive);

      expect(sent, <String>['cc']);
      expect(sender.queued, 5);
      sender.dispose();
    });

    test('they leave in order once the column is confirmed', () {
      final sent = <String>[];
      final sender = _sender(sent);
      sender.enqueue(_createCol);
      sender.enqueue(_createCard);
      sender.enqueue(_edit);
      sender.enqueue(_archive);

      sender.releaseResolved((opId) => opId == 'cc');
      expect(sent, <String>['cc', 'ck']);

      sender.releaseResolved((opId) => opId == 'cc' || opId == 'ck');
      expect(sent, <String>['cc', 'ck', 'edit', 'arch']);
      expect(sender.queued, 0);
      sender.dispose();
    });

    test('operations on other cards are not held back', () {
      final sent = <String>[];
      final sender = _sender(sent);
      sender.enqueue(_createCol);
      sender.enqueue(_createCard);
      sender.enqueue(
        const EditCardTitle(
          opId: 'other',
          cardId: 'k9',
          title: 'x',
          actorId: 'u1',
        ),
      );

      expect(sent, <String>['cc', 'other']);
      sender.dispose();
    });

    test('operations on a column created after a held one wait as well', () {
      final sent = <String>[];
      final sender = _sender(sent);
      sender.enqueue(_createCol);
      sender.enqueue(_createNext);
      sender.enqueue(
        const RenameColumn(opId: 'rn', columnId: 'col-next', title: 'R'),
      );

      expect(sent, <String>['cc']);
      sender.releaseResolved((opId) => opId == 'cc');
      expect(sent, <String>['cc', 'cc2']);
      sender.releaseResolved((opId) => opId == 'cc' || opId == 'cc2');
      expect(sent, <String>['cc', 'cc2', 'rn']);
      sender.dispose();
    });
  });

  group('refill', () {
    test('a queue held back by barriers schedules no refill', () {
      final scheduler = RecordingScheduler();
      final sender = _sender(<String>[], scheduler: scheduler, burst: 1);

      sender.enqueue(_createCol);
      sender.enqueue(_createCard);
      sender.enqueue(_edit);

      expect(scheduler.afterDelays, isEmpty);
      sender.dispose();
    });
  });
}
