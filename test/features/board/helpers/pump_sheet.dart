import 'dart:async';

import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/data/fake_board_gateway.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/presentation/board_screen.dart';
import 'package:cardo/features/board/presentation/card_drafts.dart';
import 'package:cardo/features/board/presentation/widgets/card_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'board_fixtures.dart';
import 'pump_board.dart';

const Duration sheetAnimation = Duration(milliseconds: 700);

FakeBoardGateway fakeGateway({
  Duration delay = const Duration(milliseconds: 200),
  RejectPolicy? rejectWhen,
  BoardRole role = BoardRole.editor,
}) {
  return FakeBoardGateway(
    initial: demoBoardSnapshot(currentUserRole: role),
    confirmDelay: delay,
    rejectWhen: rejectWhen,
  );
}

Future<void> openCardSheet(
  WidgetTester tester, [
  String cardId = DemoIds.handshakeCard,
]) async {
  final context = tester.element(find.byType(BoardScreen));
  unawaited(showCardSheet(context, cardId));
  await tester.pump();
  await tester.pump(sheetAnimation);
}

Future<void> closeCardSheet(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Закрыть'));
  await tester.pump();
  await tester.pump(sheetAnimation);
}

Finder get descriptionField {
  return find.byWidgetPredicate(
    (widget) =>
        widget is TextField && widget.keyboardType == TextInputType.multiline,
    skipOffstage: false,
  );
}

Finder get titleField {
  return find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        widget.keyboardType == TextInputType.text &&
        widget.textInputAction == TextInputAction.done,
  );
}

List<T> submittedOps<T extends BoardOp>(ControlledGateway gateway) {
  return [
    for (final call in gateway.calls)
      if (call.op is T) call.op as T,
  ];
}

String? draftTextOf(WidgetTester tester, String cardId) {
  return containerOf(tester).read(cardDraftsProvider)[cardId]?.text;
}
