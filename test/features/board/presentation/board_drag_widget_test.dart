import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/presentation/board_drag_controller.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/shared/widgets/card_tile.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_board.dart';

Finder _item(String cardId) => find.byKey(ValueKey<String>('item-$cardId'));

Finder _draggingTile() {
  return find.byWidgetPredicate(
    (widget) => widget is CardTile && widget.state == CardTileState.dragging,
  );
}

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

BoardSyncState _state(WidgetTester tester) {
  return containerOf(tester).read(boardNotifierProvider);
}

Future<void> _release(WidgetTester tester, _Drag drag) async {
  await drag.gesture.up();
  await tester.pump();
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  group('drag and drop', () {
    testWidgets('expanded: long press, placeholder, drop, pending, confirmed', (
      tester,
    ) async {
      await pumpBoard(tester, size: expandedSize);
      final title = 'Fractional indexing для rank';
      final gesture = await _pickUp(tester, _item(DemoIds.rankCard));
      expect(containerOf(tester).read(boardDragProvider), isNotNull);
      expect(_draggingTile(), findsOneWidget);
      expect(find.text(title), findsOneWidget);

      final target = tester.getCenter(_item('c-presence'));
      await _glide(tester, gesture, target);
      expect(find.byType(CardDropPlaceholder), findsOneWidget);
      final drag = containerOf(tester).read(boardDragProvider)!;
      expect(drag.targetColumnId, DemoIds.review);
      expect(drag.targetIndex, 1);

      await _release(tester, gesture);
      expect(containerOf(tester).read(boardDragProvider), isNull);
      expect(_draggingTile(), findsNothing);
      expect(find.byType(CardDropPlaceholder), findsNothing);
      final pending = _state(tester).pending;
      expect(pending.length, 1);
      final op = pending.single.op as MoveCard;
      expect(op.cardId, DemoIds.rankCard);
      expect(op.toColumnId, DemoIds.review);
      expect(op.afterId, 'c-refresh');
      expect(op.beforeId, 'c-presence');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('В очереди'), findsOneWidget);

      await tester.pump(confirmDelay);
      await tester.pump(const Duration(milliseconds: 300));
      final done = _state(tester);
      expect(done.pending, isEmpty);
      expect(done.lastSeq, 1285);
      expect(done.view, done.confirmed);
      expect(find.text('В очереди'), findsNothing);
      expect(
        tester.getTopLeft(find.text(title)).dx,
        greaterThan(
          tester.getTopLeft(find.text('Presence в Redis с TTL')).dx - 5,
        ),
      );
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });

    testWidgets('medium: drop into another column', (tester) async {
      await pumpBoard(tester, size: mediumSize);
      final gesture = await _pickUp(tester, _item('c-rate-limit'));
      expect(_draggingTile(), findsOneWidget);
      await _glide(tester, gesture, tester.getCenter(_item(DemoIds.rankCard)));
      expect(find.byType(CardDropPlaceholder), findsOneWidget);
      await _release(tester, gesture);
      final op = _state(tester).pending.single.op as MoveCard;
      expect(op.cardId, 'c-rate-limit');
      expect(op.toColumnId, DemoIds.inProgress);
      expect(op.afterId, DemoIds.handshakeCard);
      expect(op.beforeId, DemoIds.rankCard);
      expect(find.text('В очереди'), findsOneWidget);
      await tester.pump(confirmDelay);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_state(tester).pending, isEmpty);
      expect(_state(tester).lastSeq, 1285);
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });

    testWidgets('compact: page flips at the edge, drop in the next column', (
      tester,
    ) async {
      await pumpBoard(tester);
      final gesture = await _pickUp(tester, _item('c-rate-limit'));
      expect(_draggingTile(), findsOneWidget);
      await _glide(tester, gesture, const Offset(362, 300));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 300));
      await _glide(tester, gesture, const Offset(190, 300));
      expect(find.bySemanticsLabel('Колонка 2 из 4'), findsOneWidget);
      await _glide(tester, gesture, tester.getCenter(_item(DemoIds.rankCard)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CardDropPlaceholder), findsOneWidget);
      await _release(tester, gesture);
      final pending = _state(tester).pending;
      expect(pending.length, 1);
      final op = pending.single.op as MoveCard;
      expect(op.cardId, 'c-rate-limit');
      expect(op.toColumnId, DemoIds.inProgress);
      await tester.pump(confirmDelay);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_state(tester).pending, isEmpty);
      expect(_state(tester).lastSeq, 1285);
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });

    testWidgets('compact: leaving the edge stops flipping', (tester) async {
      await pumpBoard(tester);
      final gesture = await _pickUp(tester, _item('c-rate-limit'));
      await _glide(tester, gesture, const Offset(362, 300));
      await _glide(tester, gesture, const Offset(190, 300));
      await tester.pump(const Duration(seconds: 2));
      expect(find.bySemanticsLabel('Колонка 1 из 4'), findsOneWidget);
      await _release(tester, gesture);
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });

    for (final entry in <String, Size>{
      'compact': compactSize,
      'medium': mediumSize,
      'expanded': expandedSize,
    }.entries) {
      testWidgets(
        '${entry.key}: releasing outside any column cancels the drag',
        (tester) async {
          await pumpBoard(tester, size: entry.value);
          final gesture = await _pickUp(tester, _item(DemoIds.rankCard));
          await _glide(
            tester,
            gesture,
            tester.getCenter(find.byType(Scaffold)),
          );
          await _glide(tester, gesture, const Offset(1, 1), steps: 1);
          await tester.pump();
          await _release(tester, gesture);
          await tester.pump(const Duration(milliseconds: 300));
          expect(containerOf(tester).read(boardDragProvider), isNull);
          expect(_state(tester).pending, isEmpty);
          expect(tester.takeException(), isNull);
          await _finish(tester);
        },
      );
    }

    testWidgets('placeholder does not jump while the pointer rests', (
      tester,
    ) async {
      await pumpBoard(tester, size: expandedSize);
      final gesture = await _pickUp(tester, _item(DemoIds.rankCard));
      await _glide(tester, gesture, tester.getCenter(_item('c-presence')));
      final settled = containerOf(tester).read(boardDragProvider);
      final placeholder = tester.getTopLeft(find.byType(CardDropPlaceholder));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(containerOf(tester).read(boardDragProvider), settled);
        expect(
          tester.getTopLeft(find.byType(CardDropPlaceholder)),
          placeholder,
        );
      }
      await _release(tester, gesture);
      await _finish(tester);
    });

    testWidgets('the source card is hidden while dragging', (tester) async {
      await pumpBoard(tester, size: expandedSize);
      const title = 'Fractional indexing для rank';
      expect(find.text(title), findsOneWidget);
      final gesture = await _pickUp(tester, _item(DemoIds.rankCard));
      expect(find.text(title), findsOneWidget);
      expect(
        tester
            .widgetList<CardTile>(find.byType(CardTile))
            .where(
              (tile) =>
                  tile.title == title && tile.state != CardTileState.dragging,
            ),
        isEmpty,
      );
      await _release(tester, gesture);
      await _finish(tester);
    });

    testWidgets('releasing over nothing cancels the drag', (tester) async {
      await pumpBoard(tester, size: expandedSize);
      final gesture = await _pickUp(tester, _item(DemoIds.rankCard));
      await _glide(tester, gesture, const Offset(5, 780));
      await _release(tester, gesture);
      await tester.pump(const Duration(milliseconds: 400));
      expect(containerOf(tester).read(boardDragProvider), isNull);
      expect(_state(tester).pending, isEmpty);
      expect(find.byType(CardDropPlaceholder), findsNothing);
      await _finish(tester);
    });

    testWidgets('a quick tap does not start a drag', (tester) async {
      await pumpBoard(tester, size: expandedSize);
      await tester.tap(_item(DemoIds.rankCard));
      await tester.pump(const Duration(milliseconds: 100));
      expect(containerOf(tester).read(boardDragProvider), isNull);
      await _finish(tester);
    });

    testWidgets('expanded: edge hover autoscrolls the board', (tester) async {
      await pumpBoard(tester, size: const Size(900, 800));
      final before = tester.getTopLeft(find.text('Бэклог')).dx;
      final gesture = await _pickUp(tester, _item('c-rate-limit'));
      await _glide(tester, gesture, const Offset(890, 400));
      await tester.pump(const Duration(milliseconds: 400));
      final after = tester.getTopLeft(find.text('Бэклог')).dx;
      expect(after, lessThan(before));
      await _release(tester, gesture);
      await tester.pump(const Duration(milliseconds: 400));
      await _finish(tester);
    });
  });

  group('reduce motion', () {
    bool tilted(WidgetTester tester) {
      final transforms = tester.widgetList<Transform>(
        find.descendant(of: _draggingTile(), matching: find.byType(Transform)),
      );
      return transforms.any((transform) {
        final m = transform.transform.storage;
        return m[1].abs() > 0.0001 || m[4].abs() > 0.0001;
      });
    }

    testWidgets('feedback tilts by default', (tester) async {
      await pumpBoard(tester, size: expandedSize);
      final gesture = await _pickUp(tester, _item(DemoIds.rankCard));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tilted(tester), isTrue);
      await _release(tester, gesture);
      await _finish(tester);
    });

    testWidgets('feedback has no tilt with disableAnimations', (tester) async {
      await pumpBoard(tester, size: expandedSize, disableAnimations: true);
      final gesture = await _pickUp(tester, _item(DemoIds.rankCard));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_draggingTile(), findsOneWidget);
      expect(tilted(tester), isFalse);
      await _release(tester, gesture);
      await _finish(tester);
    });

    testWidgets('compact: flipping pages jumps without animation', (
      tester,
    ) async {
      await pumpBoard(tester, disableAnimations: true);
      final gesture = await _pickUp(tester, _item('c-rate-limit'));
      await _glide(tester, gesture, const Offset(362, 300));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.bySemanticsLabel('Колонка 2 из 4'), findsOneWidget);
      await _glide(tester, gesture, const Offset(190, 300));
      await _release(tester, gesture);
      await _finish(tester);
    });
  });
}
