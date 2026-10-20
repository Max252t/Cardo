import 'package:cardo/shared/widgets/avatar_identity.dart';
import 'package:cardo/shared/widgets/card_tile.dart';
import 'package:cardo/shared/widgets/dashed_border.dart';
import 'package:cardo/theme/cardo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

const AvatarIdentity _anya = AvatarIdentity(name: 'Аня', colorHex: '#7C4DEB');

Future<void> _pump(
  WidgetTester tester,
  CardTileState state, {
  required Brightness brightness,
  bool dense = false,
  AvatarIdentity? editor = _anya,
}) {
  return pumpApp(
    tester,
    SizedBox(
      width: 320,
      child: CardTile(
        title: 'Handshake',
        state: state,
        editingBy: editor,
        dense: dense,
      ),
    ),
    brightness: brightness,
  );
}

CardoColors _colors(WidgetTester tester) {
  return CardoColors.of(tester.element(find.byType(CardTile)));
}

CardoSizes _sizes(WidgetTester tester) {
  return CardoSizes.of(tester.element(find.byType(CardTile)));
}

BoxDecoration _surface(WidgetTester tester) {
  final container = tester.widget<AnimatedContainer>(
    find.descendant(
      of: find.byType(CardTileSurface),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return container.decoration! as BoxDecoration;
}

DashedBorderPainter? _dashed(WidgetTester tester) {
  for (final paint in tester.widgetList<CustomPaint>(
    find.descendant(
      of: find.byType(CardTileSurface),
      matching: find.byType(CustomPaint),
    ),
  )) {
    final painter = paint.foregroundPainter;
    if (painter is DashedBorderPainter) {
      return painter;
    }
  }
  return null;
}

void main() {
  for (final brightness in Brightness.values) {
    group('editing indicator on ${brightness.name}', () {
      testWidgets('pending shows the tag but keeps the dashed pending frame', (
        tester,
      ) async {
        await _pump(tester, CardTileState.pending, brightness: brightness);
        final colors = _colors(tester);
        final accent = colors.avatarSwatch(_anya.colorHex).accent;
        expect(find.text('Аня редактирует'), findsOneWidget);
        expect(find.text('В очереди'), findsOneWidget);
        final dashed = _dashed(tester);
        expect(dashed, isNotNull);
        expect(dashed!.color, colors.pendingBorder);
        expect(dashed.color, isNot(accent));
        expect(_surface(tester).border, isNull);
      });

      testWidgets('dragging shows the tag but keeps the signal frame', (
        tester,
      ) async {
        await _pump(tester, CardTileState.dragging, brightness: brightness);
        final colors = _colors(tester);
        final sizes = _sizes(tester);
        final accent = colors.avatarSwatch(_anya.colorHex).accent;
        expect(find.text('Аня редактирует'), findsOneWidget);
        expect(find.text('Перемещение'), findsOneWidget);
        final border = _surface(tester).border! as Border;
        expect(border.top.color, colors.dragBorder);
        expect(border.top.color, isNot(accent));
        expect(border.top.width, sizes.emphasisBorder);
        expect(_dashed(tester), isNull);
      });

      testWidgets('confirmed uses the editor accent for the frame', (
        tester,
      ) async {
        await _pump(tester, CardTileState.confirmed, brightness: brightness);
        final colors = _colors(tester);
        final accent = colors.avatarSwatch(_anya.colorHex).accent;
        final border = _surface(tester).border! as Border;
        expect(border.top.color, accent);
        expect(border.top.width, _sizes(tester).emphasisBorder);
        expect(find.text('Аня редактирует'), findsOneWidget);
      });

      testWidgets('rejected hides the tag and uses the nack frame', (
        tester,
      ) async {
        await _pump(tester, CardTileState.rejected, brightness: brightness);
        final colors = _colors(tester);
        expect(find.text('Аня редактирует'), findsNothing);
        final border = _surface(tester).border! as Border;
        expect(border.top.color, colors.nackBorder);
      });

      testWidgets('without an editor the frames are the plain ones', (
        tester,
      ) async {
        await _pump(
          tester,
          CardTileState.dragging,
          brightness: brightness,
          editor: null,
        );
        final colors = _colors(tester);
        final border = _surface(tester).border! as Border;
        expect(border.top.color, colors.dragBorder);
        expect(find.textContaining('редактирует'), findsNothing);
      });

      testWidgets('dense pending shows the short tag and the dashed frame', (
        tester,
      ) async {
        await _pump(
          tester,
          CardTileState.pending,
          brightness: brightness,
          dense: true,
        );
        expect(find.text('Аня'), findsOneWidget);
        expect(_dashed(tester), isNotNull);
      });

      testWidgets('the tag is announced to screen readers in every state', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        for (final state in <CardTileState>[
          CardTileState.pending,
          CardTileState.dragging,
          CardTileState.confirmed,
        ]) {
          await _pump(tester, state, brightness: brightness);
          expect(
            tester.getSemantics(find.byType(CardTile)).label,
            contains('Аня редактирует'),
            reason: state.name,
          );
        }
        handle.dispose();
      });
    });
  }
}
