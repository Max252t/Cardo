import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/features/board/presentation/widgets/card_title_editor.dart';
import 'package:cardo/features/board/presentation/widgets/card_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/pump_app.dart';
import '../../helpers/board_fixtures.dart';
import '../../helpers/pump_board.dart';
import '../../helpers/pump_sheet.dart';

const String _card = DemoIds.handshakeCard;
const String _title = 'Handshake: last_seq → дельта или снапшот';
const TextStyle _style = TextStyle(fontSize: 16);

class _HostState {
  const _HostState({this.show = true, this.editable = true});

  final bool show;
  final bool editable;
}

class _Harness {
  _Harness(this.gateway, this.container);

  final ControlledGateway gateway;
  final ProviderContainer container;
  final ValueNotifier<_HostState> host = ValueNotifier<_HostState>(
    const _HostState(),
  );

  List<EditCardTitle> get titleOps => submittedOps<EditCardTitle>(gateway);
}

Future<_Harness> _pumpEditor(WidgetTester tester) async {
  final gateway = ControlledGateway();
  final container = makeContainer(gateway: gateway);
  container.read(boardNotifierProvider);
  final harness = _Harness(gateway, container);
  addTearDown(() {
    harness.host.dispose();
    container.dispose();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: wrapApp(
        ValueListenableBuilder<_HostState>(
          valueListenable: harness.host,
          builder: (context, state, _) {
            if (!state.show) {
              return const SizedBox.shrink();
            }
            return CardTitleEditor(
              cardId: _card,
              title: _title,
              editable: state.editable,
              style: _style,
            );
          },
        ),
      ),
    ),
  );
  await tester.pump();
  return harness;
}

Future<void> _startEditing(WidgetTester tester, String text) async {
  await tester.tap(find.text(_title));
  await tester.pump();
  await tester.enterText(titleField, text);
  await tester.pump();
}

void main() {
  group('closing the sheet during an inline title edit', () {
    testWidgets('commits the typed title exactly once', (tester) async {
      final gateway = ControlledGateway();
      await pumpBoard(tester, gateway: gateway);
      await openCardSheet(tester);
      await tester.tap(find.text(_title).last);
      await tester.pump();
      await tester.enterText(titleField, 'Renamed in place');
      await tester.pump();
      expect(submittedOps<EditCardTitle>(gateway), isEmpty);

      await closeCardSheet(tester);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(CardSheet), findsNothing);
      final ops = submittedOps<EditCardTitle>(gateway);
      expect(ops.length, 1);
      expect(ops.single.cardId, _card);
      expect(ops.single.title, 'Renamed in place');
      expect(
        containerOf(tester).read(boardViewProvider).cardById(_card)!.title,
        'Renamed in place',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('does nothing when the title was not changed', (tester) async {
      final gateway = ControlledGateway();
      await pumpBoard(tester, gateway: gateway);
      await openCardSheet(tester);
      await tester.tap(find.text(_title).last);
      await tester.pump();

      await closeCardSheet(tester);
      await tester.pump(const Duration(milliseconds: 400));

      expect(submittedOps<EditCardTitle>(gateway), isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('unmounting the editor', () {
    testWidgets('while editing keeps the typed title', (tester) async {
      final harness = await _pumpEditor(tester);
      await _startEditing(tester, 'Unmounted title');

      harness.host.value = const _HostState(show: false);
      await tester.pump();

      expect(harness.titleOps.length, 1);
      expect(harness.titleOps.single.title, 'Unmounted title');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'in the same frame as editable turning off keeps the title once',
      (tester) async {
        final harness = await _pumpEditor(tester);
        await _startEditing(tester, 'Locked title');

        harness.host.value = const _HostState(editable: false);
        harness.host.value = const _HostState(show: false, editable: false);
        await tester.pump();
        await tester.pump();

        expect(harness.titleOps.length, 1);
        expect(harness.titleOps.single.title, 'Locked title');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('after editable turns off commits once, not again on dispose', (
      tester,
    ) async {
      final harness = await _pumpEditor(tester);
      await _startEditing(tester, 'Locked title');

      harness.host.value = const _HostState(editable: false);
      await tester.pump();
      expect(harness.titleOps.length, 1);
      expect(harness.titleOps.single.title, 'Locked title');
      expect(titleField, findsNothing);

      harness.host.value = const _HostState(show: false, editable: false);
      await tester.pump();
      await tester.pump();
      expect(harness.titleOps.length, 1);
    });

    testWidgets('without editing creates no operation', (tester) async {
      final harness = await _pumpEditor(tester);
      harness.host.value = const _HostState(show: false);
      await tester.pump();
      await tester.pump();
      expect(harness.titleOps, isEmpty);
    });
  });

  group('finishing the edit', () {
    testWidgets('Escape commits nothing, also not from dispose', (
      tester,
    ) async {
      final harness = await _pumpEditor(tester);
      await _startEditing(tester, 'Discarded');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(titleField, findsNothing);
      expect(harness.titleOps, isEmpty);

      harness.host.value = const _HostState(show: false);
      await tester.pump();
      await tester.pump();
      expect(harness.titleOps, isEmpty);
    });

    testWidgets('Enter commits once and dispose does not repeat it', (
      tester,
    ) async {
      final harness = await _pumpEditor(tester);
      await _startEditing(tester, 'Entered');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(titleField, findsNothing);
      expect(harness.titleOps.length, 1);
      expect(harness.titleOps.single.title, 'Entered');

      harness.host.value = const _HostState(show: false);
      await tester.pump();
      await tester.pump();
      expect(harness.titleOps.length, 1);
    });

    testWidgets('losing focus commits once and dispose does not repeat it', (
      tester,
    ) async {
      final harness = await _pumpEditor(tester);
      await _startEditing(tester, 'Blurred');

      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pump();
      expect(harness.titleOps.length, 1);
      expect(harness.titleOps.single.title, 'Blurred');

      harness.host.value = const _HostState(show: false);
      await tester.pump();
      await tester.pump();
      expect(harness.titleOps.length, 1);
    });

    testWidgets('an unchanged title creates no operation', (tester) async {
      final harness = await _pumpEditor(tester);
      await tester.tap(find.text(_title));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(harness.titleOps, isEmpty);
    });

    testWidgets('an empty or blank title creates no operation', (tester) async {
      final harness = await _pumpEditor(tester);
      await _startEditing(tester, '');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(harness.titleOps, isEmpty);

      await _startEditing(tester, '   ');
      harness.host.value = const _HostState(show: false);
      await tester.pump();
      await tester.pump();
      expect(harness.titleOps, isEmpty);
    });

    testWidgets('a title with surrounding spaces is trimmed', (tester) async {
      final harness = await _pumpEditor(tester);
      await _startEditing(tester, '  Padded  ');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(harness.titleOps.single.title, 'Padded');
    });
  });

  group('deferred commit after the container is gone', () {
    testWidgets('does not throw', (tester) async {
      final harness = await _pumpEditor(tester);
      await _startEditing(tester, 'Too late');

      WidgetsBinding.instance.addPostFrameCallback(
        (_) => harness.container.dispose(),
      );
      harness.host.value = const _HostState(editable: false);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(harness.titleOps, isEmpty);
    });

    testWidgets('dispose of the editor does not throw either', (tester) async {
      final harness = await _pumpEditor(tester);
      await _startEditing(tester, 'Too late');

      WidgetsBinding.instance.addPostFrameCallback(
        (_) => harness.container.dispose(),
      );
      harness.host.value = const _HostState(show: false);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(harness.titleOps, isEmpty);
    });
  });
}
