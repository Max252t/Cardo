import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/domain/board_model.dart';
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

String get _serverText => demoCard(_card).description;

ProviderContainer _open(ControlledGateway gateway) {
  final container = makeContainer(gateway: gateway);
  container.read(cardDraftsProvider);
  container.read(boardNotifierProvider);
  return container;
}

CardDraftsNotifier _drafts(ProviderContainer container) =>
    container.read(cardDraftsProvider.notifier);

CardDraft? _draft(ProviderContainer container) =>
    container.read(cardDraftsProvider)[_card];

BoardSyncState _board(ProviderContainer container) =>
    container.read(boardNotifierProvider);

CardSheetData _sheet(ProviderContainer container) =>
    container.read(cardSheetProvider(_card))!;

List<EditCardDescription> _descriptionCalls(ControlledGateway gateway) => [
  for (final call in gateway.calls)
    if (call.op is EditCardDescription) call.op as EditCardDescription,
];

Future<void> _settle(WidgetTester tester) => tester.pump(_tick);

void main() {
  group('edit', () {
    testWidgets('creates a draft based on the current description version', (
      tester,
    ) async {
      final container = _open(ControlledGateway());
      _drafts(container).edit(_card, 'my text');
      final draft = _draft(container)!;
      expect(draft.text, 'my text');
      expect(draft.baseDescriptionVersion, 1);
      expect(draft.conflict, isFalse);
      expect(draft.submitted, isFalse);
      expect(_sheet(container).text, 'my text');
      expect(_sheet(container).hasDraft, isTrue);
      container.dispose();
    });

    testWidgets('text equal to the server text creates nothing', (
      tester,
    ) async {
      final container = _open(ControlledGateway());
      _drafts(container).edit(_card, _serverText);
      expect(container.read(cardDraftsProvider), isEmpty);
      expect(_sheet(container).hasDraft, isFalse);
      container.dispose();
    });

    testWidgets('returning to the server text removes the draft', (
      tester,
    ) async {
      final container = _open(ControlledGateway());
      _drafts(container).edit(_card, 'changed');
      _drafts(container).edit(_card, _serverText);
      expect(container.read(cardDraftsProvider), isEmpty);
      container.dispose();
    });

    testWidgets('keeps the base version while typing on', (tester) async {
      final container = _open(ControlledGateway());
      _drafts(container)
        ..edit(_card, 'a')
        ..edit(_card, 'ab')
        ..edit(_card, 'abc');
      expect(_draft(container)!.text, 'abc');
      expect(_draft(container)!.baseDescriptionVersion, 1);
      container.dispose();
    });

    testWidgets('unknown and archived cards are ignored', (tester) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      _drafts(container).edit('zz', 'x');
      expect(container.read(cardDraftsProvider), isEmpty);
      container.read(boardNotifierProvider.notifier).archiveCard(_card);
      _drafts(container).edit(_card, 'x');
      expect(container.read(cardDraftsProvider), isEmpty);
      container.dispose();
    });

    testWidgets('a viewer cannot create a draft', (tester) async {
      final gateway = ControlledGateway(
        initial: demoBoardSnapshot(currentUserRole: BoardRole.viewer),
      );
      final container = _open(gateway);
      _drafts(container).edit(_card, 'x');
      _drafts(container).save(_card);
      expect(container.read(cardDraftsProvider), isEmpty);
      expect(gateway.calls, isEmpty);
      expect(_sheet(container).canEdit, isFalse);
      expect(_sheet(container).canSave, isFalse);
      container.dispose();
    });
  });

  group('save', () {
    testWidgets('edit, save, confirm removes the draft', (tester) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      _drafts(container).edit(_card, 'saved text');
      _drafts(container).save(_card);

      final calls = _descriptionCalls(gateway);
      expect(calls.length, 1);
      expect(calls.single.cardId, _card);
      expect(calls.single.description, 'saved text');
      expect(calls.single.baseDescriptionVersion, 1);
      expect(calls.single.actorId, DemoIds.elena);
      expect(calls.single.at, DateTime.utc(2026, 1, 1, 12));
      expect(_draft(container)!.submittedOpId, calls.single.opId);
      expect(_sheet(container).hasDraft, isFalse);
      expect(_sheet(container).text, 'saved text');
      expect(_board(container).cardStatus(_card), CardSyncStatus.pending);

      gateway.calls.single.completer.complete(const OpConfirmed(seq: 1285));
      await _settle(tester);

      expect(container.read(cardDraftsProvider), isEmpty);
      final confirmed = _board(container).confirmed.cardById(_card)!;
      expect(confirmed.description, 'saved text');
      expect(confirmed.descriptionVersion, 2);
      expect(_sheet(container).text, 'saved text');
      container.dispose();
    });

    testWidgets('without a change no operation is created', (tester) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      _drafts(container).save(_card);
      _drafts(container).edit(_card, _serverText);
      _drafts(container).save(_card);
      expect(gateway.calls, isEmpty);
      expect(_board(container).pending, isEmpty);
      container.dispose();
    });

    testWidgets('a second save while submitted does nothing', (tester) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      _drafts(container).edit(_card, 'x');
      _drafts(container)
        ..save(_card)
        ..save(_card);
      expect(_descriptionCalls(gateway).length, 1);
      container.dispose();
    });

    testWidgets('typing while submitted continues after the confirmation', (
      tester,
    ) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      _drafts(container).edit(_card, 'first');
      _drafts(container).save(_card);
      _drafts(container).edit(_card, 'first and second');
      expect(_draft(container)!.submitted, isTrue);

      gateway.calls.single.completer.complete(const OpConfirmed(seq: 1285));
      await _settle(tester);

      final draft = _draft(container)!;
      expect(draft.text, 'first and second');
      expect(draft.submitted, isFalse);
      expect(draft.conflict, isFalse);
      expect(draft.baseDescriptionVersion, 2);

      _drafts(container).save(_card);
      final calls = _descriptionCalls(gateway);
      expect(calls.length, 2);
      expect(calls.last.baseDescriptionVersion, 2);
      expect(calls.last.description, 'first and second');
      container.dispose();
    });

    testWidgets('exactly 10 000 characters are saved', (tester) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      final text = 'x' * CardLimits.descriptionMaxLength;
      _drafts(container).edit(_card, text);
      expect(_sheet(container).tooLong, isFalse);
      expect(_sheet(container).canSave, isTrue);
      _drafts(container).save(_card);
      expect(_descriptionCalls(gateway).single.description, text);
      container.dispose();
    });

    testWidgets('over the limit blocks saving and keeps the draft', (
      tester,
    ) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      final text = 'x' * (CardLimits.descriptionMaxLength + 1);
      _drafts(container).edit(_card, text);
      expect(_draft(container)!.tooLong, isTrue);
      expect(_sheet(container).tooLong, isTrue);
      expect(_sheet(container).canSave, isFalse);
      _drafts(container)
        ..save(_card)
        ..flush(_card);
      expect(gateway.calls, isEmpty);
      expect(_draft(container)!.text, text);
      expect(_board(container).pending, isEmpty);
      container.dispose();
    });

    testWidgets('a locked card is not saved', (tester) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      _drafts(container).edit(_card, 'draft');
      container
          .read(boardNotifierProvider.notifier)
          .moveCardToColumnEnd(cardId: _card, toColumnId: DemoIds.review);
      gateway.calls.single.completer.complete(
        const OpRejected(OpRejection(reason: NackReason.forbidden)),
      );
      await _settle(tester);
      expect(_board(container).cardStatus(_card), CardSyncStatus.rejected);
      expect(_sheet(container).locked, isTrue);
      expect(_sheet(container).canSave, isFalse);

      _drafts(container)
        ..save(_card)
        ..flush(_card);

      expect(_descriptionCalls(gateway), isEmpty);
      expect(_draft(container)!.text, 'draft');
      container.dispose();
    });

    testWidgets('a non-conflict nack returns the draft for a retry', (
      tester,
    ) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      _drafts(container).edit(_card, 'draft');
      _drafts(container).save(_card);
      gateway.calls.single.completer.complete(
        const OpRejected(OpRejection(reason: NackReason.forbidden)),
      );
      await _settle(tester);
      final draft = _draft(container)!;
      expect(draft.submitted, isFalse);
      expect(draft.conflict, isFalse);
      expect(draft.text, 'draft');
      await tester.pump(const Duration(milliseconds: 200));
      _drafts(container).save(_card);
      expect(_descriptionCalls(gateway).length, 2);
      container.dispose();
    });
  });

  group('conflict', () {
    testWidgets('a version_conflict nack marks the draft as conflicted', (
      tester,
    ) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      _drafts(container).edit(_card, 'mine');
      _drafts(container).save(_card);
      gateway.calls.single.completer.complete(
        const OpRejected(
          OpRejection(
            reason: NackReason.versionConflict,
            actorId: DemoIds.maxim,
          ),
        ),
      );
      await _settle(tester);

      final draft = _draft(container)!;
      expect(draft.conflict, isTrue);
      expect(draft.conflictActorId, DemoIds.maxim);
      expect(draft.text, 'mine');
      expect(draft.submitted, isFalse);
      final sheet = _sheet(container);
      expect(sheet.conflict, isNotNull);
      expect(sheet.conflict!.actorName, 'Максим');
      expect(sheet.canSave, isFalse);
      expect(sheet.text, 'mine');
      _drafts(container)
        ..save(_card)
        ..flush(_card);
      expect(_descriptionCalls(gateway).length, 1);
      container.dispose();
    });

    testWidgets('a remote edit during editing raises a conflict', (
      tester,
    ) async {
      final gateway = ControlledRemoteGateway();
      final container = _open(gateway);
      _drafts(container).edit(_card, 'mine');
      gateway.pushDescription(_card, 'theirs', descriptionVersion: 2);

      final draft = _draft(container)!;
      expect(draft.conflict, isTrue);
      expect(draft.conflictActorId, DemoIds.maxim);
      expect(draft.text, 'mine');
      expect(draft.baseDescriptionVersion, 1);
      expect(_sheet(container).conflict!.actorName, 'Максим');
      expect(_sheet(container).text, 'mine');
      container.dispose();
    });

    testWidgets('a remote edit with the same text is not a conflict', (
      tester,
    ) async {
      final gateway = ControlledRemoteGateway();
      final container = _open(gateway);
      _drafts(container).edit(_card, 'same');
      gateway.pushDescription(_card, 'same', descriptionVersion: 2);
      expect(container.read(cardDraftsProvider), isEmpty);
      expect(_sheet(container).conflict, isNull);
      expect(_sheet(container).text, 'same');
      container.dispose();
    });

    testWidgets('a remote edit without a draft changes only the text', (
      tester,
    ) async {
      final gateway = ControlledRemoteGateway();
      final container = _open(gateway);
      gateway.pushDescription(_card, 'theirs', descriptionVersion: 2);
      expect(container.read(cardDraftsProvider), isEmpty);
      expect(_sheet(container).text, 'theirs');
      container.dispose();
    });

    testWidgets('overwrite sends the draft on top of the actual version', (
      tester,
    ) async {
      final gateway = ControlledRemoteGateway();
      final container = _open(gateway);
      _drafts(container).edit(_card, 'mine');
      gateway.pushDescription(_card, 'theirs', descriptionVersion: 2);
      expect(_draft(container)!.conflict, isTrue);

      _drafts(container).overwrite(_card);

      final calls = _descriptionCalls(gateway);
      expect(calls.length, 1);
      expect(calls.single.description, 'mine');
      expect(calls.single.baseDescriptionVersion, 2);
      final draft = _draft(container)!;
      expect(draft.conflict, isFalse);
      expect(draft.submitted, isTrue);
      expect(_sheet(container).conflict, isNull);

      gateway.calls.single.completer.complete(const OpConfirmed(seq: 1286));
      await _settle(tester);
      expect(container.read(cardDraftsProvider), isEmpty);
      expect(_board(container).confirmed.cardById(_card)!.description, 'mine');
      expect(_sheet(container).text, 'mine');
      await gateway.dispose();
      container.dispose();
    });

    testWidgets('overwrite after a nack uses the pushed version', (
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
          ),
        ),
      );
      gateway.pushDescription(_card, 'theirs', descriptionVersion: 3);
      await _settle(tester);
      expect(_draft(container)!.conflict, isTrue);

      _drafts(container).overwrite(_card);

      final calls = _descriptionCalls(gateway);
      expect(calls.length, 2);
      expect(calls.last.baseDescriptionVersion, 3);
      expect(calls.last.description, 'mine');
      await tester.pump(const Duration(milliseconds: 200));
      await gateway.dispose();
      container.dispose();
    });

    testWidgets('overwrite without a conflict does nothing', (tester) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      _drafts(container).edit(_card, 'mine');
      _drafts(container).overwrite(_card);
      expect(gateway.calls, isEmpty);
      expect(_draft(container)!.submitted, isFalse);
      container.dispose();
    });

    testWidgets('discard brings back the server text', (tester) async {
      final gateway = ControlledRemoteGateway();
      final container = _open(gateway);
      _drafts(container).edit(_card, 'mine');
      gateway.pushDescription(_card, 'theirs', descriptionVersion: 2);
      expect(_sheet(container).text, 'mine');

      _drafts(container).discard(_card);

      expect(container.read(cardDraftsProvider), isEmpty);
      expect(_sheet(container).text, 'theirs');
      expect(_sheet(container).conflict, isNull);
      expect(gateway.calls, isEmpty);
      await gateway.dispose();
      container.dispose();
    });

    testWidgets('flush does not send a conflicted draft', (tester) async {
      final gateway = ControlledRemoteGateway();
      final container = _open(gateway);
      _drafts(container).edit(_card, 'mine');
      gateway.pushDescription(_card, 'theirs', descriptionVersion: 2);
      _drafts(container).flush(_card);
      expect(gateway.calls, isEmpty);
      expect(_draft(container)!.text, 'mine');
      await gateway.dispose();
      container.dispose();
    });
  });

  group('flush', () {
    testWidgets('sends a changed draft', (tester) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      _drafts(container).edit(_card, 'on close');
      _drafts(container).flush(_card);
      expect(_descriptionCalls(gateway).single.description, 'on close');
      container.dispose();
    });

    testWidgets('without a draft it is a no-op', (tester) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      _drafts(container).flush(_card);
      expect(gateway.calls, isEmpty);
      container.dispose();
    });
  });

  group('lifetime', () {
    testWidgets('a draft survives while the container lives', (tester) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      final subscription = container.listen(
        cardSheetProvider(_card),
        (previous, next) {},
      );
      _drafts(container).edit(_card, 'kept');
      subscription.close();
      await tester.pump(const Duration(seconds: 1));
      expect(_draft(container)!.text, 'kept');
      expect(_sheet(container).text, 'kept');
      container.dispose();
    });

    testWidgets('an archived card drops its draft', (tester) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      _drafts(container).edit(_card, 'kept');
      container.read(boardNotifierProvider.notifier).archiveCard(_card);
      gateway.calls.single.completer.complete(const OpConfirmed(seq: 1285));
      await _settle(tester);
      expect(container.read(cardDraftsProvider), isEmpty);
      expect(container.read(cardSheetProvider(_card)), isNull);
      container.dispose();
    });
  });

  group('BoardNotifier.editCardDescription', () {
    testWidgets('enqueues a sent operation and returns its id', (tester) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      final opId = container
          .read(boardNotifierProvider.notifier)
          .editCardDescription(
            cardId: _card,
            description: 'direct',
            baseDescriptionVersion: 1,
          );
      expect(opId, 'id-0');
      final pending = _board(container).pending.single;
      expect(pending.status, PendingOpStatus.sent);
      final op = pending.op as EditCardDescription;
      expect(op.opId, opId);
      expect(op.actorId, DemoIds.elena);
      expect(op.at, DateTime.utc(2026, 1, 1, 12));
      expect(_board(container).view.cardById(_card)!.description, 'direct');
      expect(
        _board(container).confirmed.cardById(_card)!.description,
        _serverText,
      );
      container.dispose();
    });

    testWidgets('rejects viewers, unknown, archived and oversized input', (
      tester,
    ) async {
      final viewerGateway = ControlledGateway(
        initial: demoBoardSnapshot(currentUserRole: BoardRole.viewer),
      );
      final viewer = _open(viewerGateway);
      expect(
        viewer
            .read(boardNotifierProvider.notifier)
            .editCardDescription(
              cardId: _card,
              description: 'x',
              baseDescriptionVersion: 1,
            ),
        isNull,
      );
      expect(viewerGateway.calls, isEmpty);
      viewer.dispose();

      final gateway = ControlledGateway();
      final container = _open(gateway);
      final notifier = container.read(boardNotifierProvider.notifier);
      expect(
        notifier.editCardDescription(
          cardId: 'zz',
          description: 'x',
          baseDescriptionVersion: 1,
        ),
        isNull,
      );
      expect(
        notifier.editCardDescription(
          cardId: _card,
          description: 'x' * (CardLimits.descriptionMaxLength + 1),
          baseDescriptionVersion: 1,
        ),
        isNull,
      );
      expect(gateway.calls, isEmpty);
      notifier.archiveCard(_card);
      expect(
        notifier.editCardDescription(
          cardId: _card,
          description: 'x',
          baseDescriptionVersion: 1,
        ),
        isNull,
      );
      expect(gateway.calls.length, 1);
      container.dispose();
    });

    testWidgets('remote updates move confirmed state and seq forward', (
      tester,
    ) async {
      final gateway = ControlledRemoteGateway();
      final container = _open(gateway);
      gateway.pushDescription(
        _card,
        'theirs',
        descriptionVersion: 2,
        seq: 1290,
      );
      final state = _board(container);
      expect(state.lastSeq, 1290);
      expect(state.confirmed.seq, 1290);
      expect(state.confirmed.cardById(_card)!.description, 'theirs');
      gateway.pushDescription(_card, 'older', descriptionVersion: 2, seq: 1280);
      expect(_board(container).lastSeq, 1290);
      await gateway.dispose();
      container.dispose();
    });
  });
}
