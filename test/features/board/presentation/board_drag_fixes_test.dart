import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/presentation/board_drag_controller.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/shared/widgets/card_tile.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_board.dart';

Finder _item(String cardId) => find.byKey(ValueKey<String>('item-$cardId'));

class _Drag {
  _Drag(this.gesture, this.position);

  final TestGesture gesture;
  Offset position;
}

Future<_Drag> _pickUp(WidgetTester tester, Finder card) async {
  final start = tester.getCenter(card);
  final gesture = await tester.startGesture(start);
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  await gesture.moveBy(const Offset(0, 6));
  await tester.pump();
  return _Drag(gesture, start + const Offset(0, 6));
}

Future<void> _glide(
  WidgetTester tester,
  _Drag drag,
  Offset target, {
  int steps = 8,
}) async {
  final from = drag.position;
  for (var i = 1; i <= steps; i++) {
    await drag.gesture.moveTo(Offset.lerp(from, target, i / steps)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
  drag.position = target;
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
}

BoardSyncState _state(WidgetTester tester) {
  return containerOf(tester).read(boardNotifierProvider);
}

double _backlogX(WidgetTester tester) {
  return tester.getTopLeft(find.text('Бэклог').first).dx;
}

void main() {
  group('column header drop target', () {
    testWidgets('dragging the first card onto its header keeps it first', (
      tester,
    ) async {
      await pumpBoard(tester, size: expandedSize);
      final drag = await _pickUp(tester, _item(DemoIds.handshakeCard));
      await _glide(tester, drag, tester.getCenter(_item(DemoIds.rankCard)));
      expect(containerOf(tester).read(boardDragProvider)!.targetIndex, 1);
      await _glide(tester, drag, tester.getCenter(find.text('В работе')));
      final state = containerOf(tester).read(boardDragProvider)!;
      expect(state.targetColumnId, DemoIds.inProgress);
      expect(state.targetIndex, 0);
      final placeholder = tester.getTopLeft(find.byType(CardDropPlaceholder));
      expect(
        placeholder.dy,
        lessThan(tester.getTopLeft(_item(DemoIds.rankCard)).dy),
      );
      await drag.gesture.up();
      await tester.pump();
      expect(_state(tester).pending, isEmpty);
      expect(
        _state(tester).view.cardsIn(DemoIds.inProgress).first.id,
        DemoIds.handshakeCard,
      );
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });

    testWidgets('header of another column targets its first slot', (
      tester,
    ) async {
      await pumpBoard(tester, size: expandedSize);
      final drag = await _pickUp(tester, _item(DemoIds.rankCard));
      await _glide(tester, drag, tester.getCenter(find.text('Ревью')));
      final state = containerOf(tester).read(boardDragProvider)!;
      expect(state.targetColumnId, DemoIds.review);
      expect(state.targetIndex, 0);
      await drag.gesture.up();
      await tester.pump();
      expect(
        _state(tester).view.cardsIn(DemoIds.review).first.id,
        DemoIds.rankCard,
      );
      await _finish(tester);
    });
  });

  group('edge timers stop when the drag ends without the draggable', () {
    Future<void> rejectAuditAfterOneSecond(
      WidgetTester tester,
      Size size,
    ) async {
      await pumpBoard(
        tester,
        size: size,
        delay: const Duration(seconds: 1),
        rejectWhen: (op) =>
            const OpRejection(reason: NackReason.versionConflict),
      );
      containerOf(tester)
          .read(boardNotifierProvider.notifier)
          .moveCardToIndex(
            cardId: 'c-audit',
            toColumnId: DemoIds.backlog,
            index: 0,
          );
      await tester.pump();
    }

    testWidgets('autoscroll stops after the dragged card is rejected', (
      tester,
    ) async {
      await rejectAuditAfterOneSecond(tester, const Size(900, 800));
      final before = _backlogX(tester);
      final drag = await _pickUp(tester, _item('c-audit'));
      expect(containerOf(tester).read(boardDragProvider), isNotNull);
      await _glide(tester, drag, const Offset(890, 400));
      expect(_backlogX(tester), lessThan(before));

      await tester.pump(const Duration(milliseconds: 30));
      expect(_state(tester).cardStatus('c-audit'), CardSyncStatus.rejected);
      expect(containerOf(tester).read(boardDragProvider), isNull);
      final stopped = _backlogX(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_backlogX(tester), stopped);

      await drag.gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_backlogX(tester), stopped);
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });

    testWidgets('page flip is cancelled after the dragged card is rejected', (
      tester,
    ) async {
      await rejectAuditAfterOneSecond(tester, compactSize);
      final drag = await _pickUp(tester, _item('c-audit'));
      expect(containerOf(tester).read(boardDragProvider), isNotNull);
      await _glide(tester, drag, const Offset(362, 300));
      expect(find.bySemanticsLabel('Колонка 1 из 4'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(_state(tester).cardStatus('c-audit'), CardSyncStatus.rejected);
      expect(containerOf(tester).read(boardDragProvider), isNull);
      expect(find.bySemanticsLabel('Колонка 1 из 4'), findsOneWidget);
      await drag.gesture.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });

    testWidgets(
      'long press on a card rejected mid-press does not start a drag',
      (tester) async {
        await rejectAuditAfterOneSecond(tester, expandedSize);
        await tester.pump(const Duration(milliseconds: 650));
        final start = tester.getCenter(_item('c-audit'));
        final gesture = await tester.startGesture(start);
        await tester.pump(const Duration(milliseconds: 400));
        expect(_state(tester).cardStatus('c-audit'), CardSyncStatus.rejected);
        await tester.pump(const Duration(milliseconds: 200));
        expect(_state(tester).cardStatus('c-audit'), CardSyncStatus.rejected);
        expect(containerOf(tester).read(boardDragProvider), isNull);
        await gesture.up();
        await tester.pump();
        await _finish(tester);
      },
    );
  });

  group('right-to-left', () {
    testWidgets('expanded: the end edge (left) autoscrolls toward the end', (
      tester,
    ) async {
      await pumpBoard(
        tester,
        size: const Size(900, 800),
        textDirection: TextDirection.rtl,
      );
      final before = _backlogX(tester);
      final drag = await _pickUp(tester, _item('c-rate-limit'));
      await _glide(tester, drag, const Offset(10, 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_backlogX(tester), greaterThan(before));
      await drag.gesture.up();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });

    testWidgets('expanded: the start edge (right) does not scroll past start', (
      tester,
    ) async {
      await pumpBoard(
        tester,
        size: const Size(900, 800),
        textDirection: TextDirection.rtl,
      );
      final before = _backlogX(tester);
      final drag = await _pickUp(tester, _item('c-rate-limit'));
      await _glide(tester, drag, const Offset(890, 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_backlogX(tester), before);
      await drag.gesture.up();
      await tester.pump(const Duration(milliseconds: 400));
      await _finish(tester);
    });

    testWidgets('compact: the end edge (left) flips to the next column', (
      tester,
    ) async {
      await pumpBoard(tester, textDirection: TextDirection.rtl);
      final drag = await _pickUp(tester, _item('c-rate-limit'));
      await _glide(tester, drag, const Offset(13, 300));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 300));
      await _glide(tester, drag, const Offset(190, 300));
      expect(find.bySemanticsLabel('Колонка 2 из 4'), findsOneWidget);
      await drag.gesture.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });

    testWidgets('compact: the start edge (right) stays on the first column', (
      tester,
    ) async {
      await pumpBoard(tester, textDirection: TextDirection.rtl);
      final drag = await _pickUp(tester, _item('c-rate-limit'));
      await _glide(tester, drag, const Offset(362, 300));
      await tester.pump(const Duration(seconds: 1));
      await _glide(tester, drag, const Offset(190, 300));
      expect(find.bySemanticsLabel('Колонка 1 из 4'), findsOneWidget);
      await drag.gesture.up();
      await tester.pump();
      await _finish(tester);
    });
  });
}
