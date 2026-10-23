import 'package:cardo/features/board/domain/board_model.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_session.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/domain/card_draft.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/features/board/presentation/card_drafts.dart';
import 'package:cardo/features/board/presentation/card_sheet_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/board_fixtures.dart';
import '../helpers/controlled_remote_gateway.dart';

const String _card = DemoIds.handshakeCard;
const Duration _tick = Duration(milliseconds: 1);
const OpRejection _conflict = OpRejection(
  reason: NackReason.versionConflict,
  actorId: DemoIds.maxim,
);

ProviderContainer _open(ControlledGateway gateway) {
  final container = makeContainer(gateway: gateway);
  container.read(cardDraftsProvider);
  container.read(boardNotifierProvider);
  return container;
}

CardDraftsNotifier _drafts(ProviderContainer container) =>
    container.read(cardDraftsProvider.notifier);

CardDraft? _draft(ProviderContainer container, [String cardId = _card]) =>
    container.read(cardDraftsProvider)[cardId];

CardSheetData _sheet(ProviderContainer container) =>
    container.read(cardSheetProvider(_card))!;

List<EditCardDescription> _descriptionCalls(ControlledGateway gateway) => [
  for (final call in gateway.calls)
    if (call.op is EditCardDescription) call.op as EditCardDescription,
];

void _rejectMove(ControlledGateway gateway, ProviderContainer container) {
  container
      .read(boardNotifierProvider.notifier)
      .moveCardToColumnEnd(cardId: _card, toColumnId: DemoIds.review);
  gateway.calls.last.completer.complete(
    const OpRejected(OpRejection(reason: NackReason.forbidden)),
  );
}

class _EditRights extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool value) => state = value;
}

final _editRightsProvider = NotifierProvider<_EditRights, bool>(
  _EditRights.new,
);

void main() {
  group('a confirmation that overtakes a remote edit', () {
    testWidgets('does not overwrite the remote text silently', (tester) async {
      final gateway = ControlledRemoteGateway();
      final container = _open(gateway);
      _drafts(container).edit(_card, 'mine');
      _drafts(container).save(_card);
      final call = gateway.calls.single;

      gateway.pushDescription(
        _card,
        'theirs',
        descriptionVersion: 3,
        seq: 1286,
      );
      expect(_draft(container)!.submitted, isTrue);
      call.completer.complete(const OpConfirmed(seq: 1285));
      await tester.pump(_tick);

      final draft = _draft(container)!;
      expect(draft.conflict, isTrue);
      expect(draft.conflictActorId, DemoIds.maxim);
      expect(draft.text, 'mine');
      expect(draft.baseDescriptionVersion, 2);
      expect(_sheet(container).conflict!.actorName, 'Максим');
      _drafts(container).flush(_card);
      expect(_descriptionCalls(gateway).length, 1);
      expect(_sheet(container).text, 'mine');
      await gateway.dispose();
      container.dispose();
    });
  });

  group('a card that is not confirmed yet', () {
    testWidgets('keeps the draft and sends it after the create', (
      tester,
    ) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      container
          .read(boardNotifierProvider.notifier)
          .createCard(columnId: DemoIds.backlog, title: 'Fresh');
      final created = gateway.calls.single;
      final cardId = (created.op as CreateCard).cardId;

      _drafts(container).edit(cardId, 'text for fresh');
      expect(_draft(container, cardId)!.text, 'text for fresh');
      expect(_draft(container, cardId)!.baseDescriptionVersion, 1);
      _drafts(container).flush(cardId);
      expect(_descriptionCalls(gateway), isEmpty);
      expect(_draft(container, cardId)!.text, 'text for fresh');

      created.completer.complete(const OpConfirmed(seq: 1285));
      await tester.pump(_tick);

      final calls = _descriptionCalls(gateway);
      expect(calls.length, 1);
      expect(calls.single.cardId, cardId);
      expect(calls.single.description, 'text for fresh');
      expect(calls.single.baseDescriptionVersion, 1);
      container.dispose();
    });

    testWidgets('drops the draft when the create is rejected', (tester) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      container
          .read(boardNotifierProvider.notifier)
          .createCard(columnId: DemoIds.backlog, title: 'Fresh');
      final created = gateway.calls.single;
      final cardId = (created.op as CreateCard).cardId;
      _drafts(container).edit(cardId, 'text for fresh');

      created.completer.complete(
        const OpRejected(OpRejection(reason: NackReason.forbidden)),
      );
      await tester.pump(_tick);

      expect(container.read(cardDraftsProvider), isEmpty);
      expect(container.read(lostDraftProvider)!.text, 'text for fresh');
      await tester.pump(const Duration(milliseconds: 200));
      container.dispose();
    });
  });

  group('an archived card', () {
    testWidgets('reports the unsaved text before dropping the draft', (
      tester,
    ) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      _drafts(container).edit(_card, 'precious');
      container.read(boardNotifierProvider.notifier).archiveCard(_card);

      expect(container.read(cardDraftsProvider), isEmpty);
      final lost = container.read(lostDraftProvider)!;
      expect(lost.cardId, _card);
      expect(lost.text, 'precious');
      container.read(lostDraftProvider.notifier).clear();
      expect(container.read(lostDraftProvider), isNull);
      container.dispose();
    });

    testWidgets('reports nothing when there was no draft', (tester) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      container.read(boardNotifierProvider.notifier).archiveCard(_card);
      expect(container.read(lostDraftProvider), isNull);
      container.dispose();
    });
  });

  group('flush that could not be sent at once', () {
    testWidgets('is sent after the previous save is confirmed', (tester) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      _drafts(container).edit(_card, 'first');
      _drafts(container).save(_card);
      _drafts(container).edit(_card, 'first and more');
      _drafts(container).flush(_card);
      expect(_descriptionCalls(gateway).length, 1);
      expect(_draft(container)!.flushRequested, isTrue);

      gateway.calls.single.completer.complete(const OpConfirmed(seq: 1285));
      await tester.pump(_tick);

      final calls = _descriptionCalls(gateway);
      expect(calls.length, 2);
      expect(calls.last.description, 'first and more');
      expect(calls.last.baseDescriptionVersion, 2);
      expect(_draft(container)!.submitted, isTrue);
      container.dispose();
    });

    testWidgets('is sent after the nack hold on another operation ends', (
      tester,
    ) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      _rejectMove(gateway, container);
      await tester.pump(_tick);
      expect(_sheet(container).locked, isTrue);

      _drafts(container).edit(_card, 'typed while locked');
      _drafts(container).flush(_card);
      expect(_descriptionCalls(gateway), isEmpty);

      await tester.pump(const Duration(milliseconds: 150));

      final calls = _descriptionCalls(gateway);
      expect(calls.length, 1);
      expect(calls.single.description, 'typed while locked');
      container.dispose();
    });

    testWidgets('typing after the flush cancels the request', (tester) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      _rejectMove(gateway, container);
      await tester.pump(_tick);
      _drafts(container).edit(_card, 'a');
      _drafts(container).flush(_card);
      _drafts(container).edit(_card, 'ab');
      expect(_draft(container)!.flushRequested, isFalse);
      await tester.pump(const Duration(milliseconds: 150));
      expect(_descriptionCalls(gateway), isEmpty);
      container.dispose();
    });

    testWidgets('a conflicted or oversized draft is never auto-sent', (
      tester,
    ) async {
      final gateway = ControlledRemoteGateway();
      final container = _open(gateway);
      _drafts(container)
          .edit(_card, 'x' * (CardLimits.descriptionMaxLength + 1));
      _drafts(container).flush(_card);
      await tester.pump(const Duration(milliseconds: 150));
      expect(_descriptionCalls(gateway), isEmpty);
      await gateway.dispose();
      container.dispose();
    });
  });

  group('conflict resolution waits for the actual version', () {
    testWidgets('buttons are inert until the event with the new version', (
      tester,
    ) async {
      final gateway = ControlledRemoteGateway();
      final container = _open(gateway);
      _drafts(container).edit(_card, 'mine');
      _drafts(container).save(_card);
      gateway.calls.single.completer.complete(
        const OpRejected(
          OpRejection(
            reason: NackReason.versionConflict,
            actorId: DemoIds.maxim,
            atSeq: 1290,
          ),
        ),
      );
      await tester.pump(_tick);

      expect(_draft(container)!.conflict, isTrue);
      expect(_draft(container)!.conflictAtSeq, 1290);
      expect(_sheet(container).conflict!.resolvable, isFalse);

      _drafts(container).overwrite(_card);
      _drafts(container).discard(_card);
      expect(_descriptionCalls(gateway).length, 1);
      expect(_draft(container)!.conflict, isTrue);

      gateway.pushDescription(
        _card,
        'theirs',
        descriptionVersion: 2,
        seq: 1290,
      );
      expect(_sheet(container).conflict!.resolvable, isTrue);

      _drafts(container).overwrite(_card);
      final calls = _descriptionCalls(gateway);
      expect(calls.length, 2);
      expect(calls.last.baseDescriptionVersion, 2);
      expect(calls.last.description, 'mine');
      await tester.pump(const Duration(milliseconds: 200));
      await gateway.dispose();
      container.dispose();
    });

    testWidgets('a newer description version also unlocks the buttons', (
      tester,
    ) async {
      final gateway = ControlledRemoteGateway();
      final container = _open(gateway);
      _drafts(container).edit(_card, 'mine');
      _drafts(container).save(_card);
      gateway.calls.single.completer.complete(
        const OpRejected(
          OpRejection(
            reason: NackReason.versionConflict,
            actorId: DemoIds.maxim,
            atSeq: 1300,
          ),
        ),
      );
      await tester.pump(_tick);
      expect(_sheet(container).conflict!.resolvable, isFalse);
      gateway.pushDescription(
        _card,
        'theirs',
        descriptionVersion: 2,
        seq: 1285,
      );
      expect(_sheet(container).conflict!.resolvable, isTrue);
      _drafts(container).discard(_card);
      expect(container.read(cardDraftsProvider), isEmpty);
      expect(_sheet(container).text, 'theirs');
      await tester.pump(const Duration(milliseconds: 200));
      await gateway.dispose();
      container.dispose();
    });

    testWidgets('a nack without a sequence is resolvable at once', (
      tester,
    ) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      _drafts(container).edit(_card, 'mine');
      _drafts(container).save(_card);
      gateway.calls.single.completer.complete(const OpRejected(_conflict));
      await tester.pump(_tick);
      expect(_sheet(container).conflict!.resolvable, isTrue);
      _drafts(container).discard(_card);
      expect(container.read(cardDraftsProvider), isEmpty);
      await tester.pump(const Duration(milliseconds: 200));
      container.dispose();
    });
  });

  group('lock', () {
    testWidgets('a description conflict does not lock the card', (
      tester,
    ) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      _drafts(container).edit(_card, 'mine');
      _drafts(container).save(_card);
      gateway.calls.single.completer.complete(const OpRejected(_conflict));
      await tester.pump(_tick);

      expect(_board(container).cardStatus(_card), CardSyncStatus.rejected);
      expect(_sheet(container).locked, isFalse);
      expect(_sheet(container).editable, isTrue);
      expect(container.read(cardNackProvider(_card)), isNull);
      await tester.pump(const Duration(milliseconds: 200));
      container.dispose();
    });

    testWidgets('another rejected operation still locks the card', (
      tester,
    ) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      _rejectMove(gateway, container);
      await tester.pump(_tick);
      expect(_sheet(container).locked, isTrue);
      expect(
        container.read(cardNackProvider(_card))!.rejection.reason,
        NackReason.forbidden,
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(_sheet(container).locked, isFalse);
      expect(container.read(cardNackProvider(_card)), isNull);
      container.dispose();
    });
  });

  group('rights lost during editing', () {
    testWidgets('a viewer sees the server text and the draft survives', (
      tester,
    ) async {
      final gateway = ControlledGateway();
      final container = ProviderContainer(
        overrides: [
          boardGatewayProvider.overrideWithValue(gateway),
          idGeneratorProvider.overrideWithValue(IdSequence().call),
          nowProvider.overrideWithValue(() => DateTime.utc(2026, 1, 1, 12)),
          canEditBoardProvider.overrideWith(
            (ref) => ref.watch(_editRightsProvider),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(cardDraftsProvider);
      container.read(boardNotifierProvider);
      final serverText = demoCard(_card).description;

      _drafts(container).edit(_card, 'in progress');
      expect(_sheet(container).text, 'in progress');

      container.read(_editRightsProvider.notifier).set(false);
      final viewer = _sheet(container);
      expect(viewer.canEdit, isFalse);
      expect(viewer.text, serverText);
      expect(viewer.hasDraft, isFalse);
      expect(viewer.tooLong, isFalse);
      expect(viewer.conflict, isNull);
      expect(_draft(container)!.text, 'in progress');

      container.read(_editRightsProvider.notifier).set(true);
      expect(_sheet(container).text, 'in progress');
      expect(_sheet(container).hasDraft, isTrue);
      await tester.pump(_tick);
    });
  });

  group('providers are released when unused', () {
    testWidgets('sheet and nack providers dispose without listeners', (
      tester,
    ) async {
      final container = _open(ControlledGateway());
      _drafts(container).edit(_card, 'kept');
      expect(container.read(cardSheetProvider(_card)), isNotNull);
      await tester.pump(_tick);
      expect(_draft(container)!.text, 'kept');
      expect(container.read(cardSheetProvider(_card))!.text, 'kept');
      container.dispose();
    });
  });
}

BoardSyncState _board(ProviderContainer container) =>
    container.read(boardNotifierProvider);
