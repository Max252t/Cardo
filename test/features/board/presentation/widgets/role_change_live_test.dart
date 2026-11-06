import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/data/fake_board_gateway.dart';
import 'package:cardo/features/board/presentation/board_drag_controller.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/features/board/presentation/widgets/board_column_header.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_board.dart';

Finder item(String cardId) => find.byKey(ValueKey<String>('item-$cardId'));

void main() {
  for (final entry in <String, Size>{
    '375': compactSize,
    '1280': expandedSize,
  }.entries) {
    testWidgets('${entry.key}: a role change to viewer removes the add button '
        'and the drag at once', (tester) async {
      final gateway = FakeBoardGateway(confirmDelay: Duration.zero);
      await pumpBoard(tester, size: entry.value, gateway: gateway);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(AddCardButton), findsWidgets);
      expect(canEditOf(tester), isTrue);

      gateway.server.changeRole(DemoIds.elena, BoardRole.viewer);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(AddCardButton), findsNothing);
      expect(canEditOf(tester), isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a long press after the downgrade starts no drag', (
    tester,
  ) async {
    final gateway = FakeBoardGateway(confirmDelay: Duration.zero);
    await pumpBoard(tester, size: expandedSize, gateway: gateway);
    await tester.pump(const Duration(milliseconds: 50));
    gateway.server.changeRole(DemoIds.elena, BoardRole.viewer);
    await tester.pump(const Duration(milliseconds: 50));

    final start = tester.getCenter(item(DemoIds.rankCard));
    final gesture = await tester.startGesture(start);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(0, 200));
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));

    expect(containerOf(tester).read(boardDragProvider), isNull);
    expect(gateway.server.receivedOps, isEmpty);
  });

  testWidgets('the add button comes back when the role is restored', (
    tester,
  ) async {
    final gateway = FakeBoardGateway(confirmDelay: Duration.zero);
    await pumpBoard(tester, size: expandedSize, gateway: gateway);
    await tester.pump(const Duration(milliseconds: 50));
    gateway.server.changeRole(DemoIds.elena, BoardRole.viewer);
    await tester.pump(const Duration(milliseconds: 50));

    gateway.server.changeRole(DemoIds.elena, BoardRole.editor);
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(AddCardButton), findsWidgets);
  });
}

bool canEditOf(WidgetTester tester) {
  final container = containerOf(tester);
  return container.read(canEditBoardProvider);
}
