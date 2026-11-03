import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/data/fake_board_gateway.dart';
import 'package:cardo/features/board/data/sync_signal.dart';
import 'package:cardo/features/board/domain/board_event.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/gateway_probe.dart';

const String _card = DemoIds.handshakeCard;

EditCardDescription _edit(String text, {int base = 1, String opId = 'op'}) {
  return EditCardDescription(
    opId: opId,
    cardId: _card,
    description: text,
    baseDescriptionVersion: base,
    actorId: DemoIds.elena,
  );
}

Future<(FakeBoardGateway, GatewayProbe)> _open({
  RejectPolicy? rejectWhen,
  bool announceConflicts = true,
}) async {
  final gateway = FakeBoardGateway(
    confirmDelay: Duration.zero,
    rejectWhen: rejectWhen,
    announceConflicts: announceConflicts,
  );
  final probe = GatewayProbe(gateway);
  await probe.settle();
  addTearDown(probe.dispose);
  return (gateway, probe);
}

void main() {
  test('a repeated op id returns the stored event as a duplicate', () async {
    final (gateway, probe) = await _open();
    await probe.send(_edit('once', opId: 'same'));
    await probe.send(_edit('once', opId: 'same'));
    final event = probe.events.single as CardEditedEvent;
    expect(event.opId, 'same');
    expect(probe.duplicates, <String>['same']);
    expect(gateway.serverBoard.cardById(_card)!.descriptionVersion, 2);
    expect(gateway.serverBoard.seq, event.seq);
  });

  test('a repeated op id returns the stored nack', () async {
    final (gateway, probe) = await _open();
    gateway.simulateRemoteDescriptionEdit(
      cardId: _card,
      text: 'theirs',
      actorId: DemoIds.maxim,
    );
    await probe.send(_edit('mine', opId: 'same'));
    await probe.send(_edit('mine', opId: 'same'));
    expect(probe.nacks.length, 2);
    expect(
      probe.nacks.map((nack) => nack.rejection.reason),
      everyElement(NackReason.versionConflict),
    );
    expect(probe.nacks.first.rejection, probe.nacks.last.rejection);
  });

  test('a different op id with the same content is a new operation', () async {
    final (_, probe) = await _open();
    await probe.send(_edit('once', opId: 'a'));
    await probe.send(_edit('once', opId: 'b'));
    expect(probe.nacks.single.opId, 'b');
    expect(probe.nacks.single.rejection.reason, NackReason.versionConflict);
  });

  test('forced rejections are not remembered', () async {
    var rejectNext = true;
    final (_, probe) = await _open(
      rejectWhen: (op) {
        if (!rejectNext) {
          return null;
        }
        rejectNext = false;
        return const OpRejection(reason: NackReason.internal);
      },
    );
    await probe.send(_edit('retry', opId: 'same'));
    await probe.send(_edit('retry', opId: 'same'));
    expect(probe.nacks.single.rejection.reason, NackReason.internal);
    expect(probe.events.single.opId, 'same');
  });

  test('announced conflicts deliver the edit before the nack', () async {
    final (gateway, probe) = await _open();
    gateway.simulateRemoteDescriptionEdit(
      cardId: _card,
      text: 'theirs',
      actorId: DemoIds.maxim,
    );
    expect(probe.events, isEmpty);
    await probe.send(_edit('mine'));
    final remote = probe.events.single as CardEditedEvent;
    expect(remote.description, 'theirs');
    expect(
      probe.signals.indexWhere((s) => s is EventsSignal),
      lessThan(probe.signals.indexWhere((s) => s is NackSignal)),
    );
  });

  test('without announcements the edit is delivered on demand', () async {
    final (gateway, probe) = await _open(announceConflicts: false);
    gateway.simulateRemoteDescriptionEdit(
      cardId: _card,
      text: 'theirs',
      actorId: DemoIds.maxim,
    );
    await probe.send(_edit('mine'));
    expect(probe.nacks.single.rejection.atSeq, gateway.serverBoard.seq);
    expect(probe.events, isEmpty);
    gateway.publishCard(_card);
    await probe.settle();
    final remote = probe.events.single as CardEditedEvent;
    expect(remote.seq, gateway.serverBoard.seq);
    expect(remote.actorId, DemoIds.maxim);
    expect(remote.descriptionVersion, 2);
  });
}
