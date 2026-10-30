import 'dart:ui' show Tristate;

import 'package:cardo/features/board/domain/board_model.dart';
import 'package:cardo/features/board/presentation/board_view_data.dart';
import 'package:cardo/features/board/presentation/widgets/card_editor_parts.dart';
import 'package:cardo/features/board/presentation/widgets/card_editor_style.dart';
import 'package:cardo/features/board/presentation/widgets/column_marker.dart';
import 'package:cardo/theme/cardo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../helpers/pump_app.dart';

const ColumnInfo _column = ColumnInfo(
  id: 'col',
  title: 'В работе',
  marker: ColumnMarker.inProgress,
);

Future<void> _pumpChip(
  WidgetTester tester,
  CardEditorVariant variant, {
  double textScale = 1,
}) async {
  await pumpApp(
    tester,
    Builder(
      builder: (context) => CardColumnChip(
        column: _column,
        style: CardEditorStyle.of(context, variant),
      ),
    ),
    textScale: textScale,
  );
}

Future<void> _pumpButton(
  WidgetTester tester,
  CardEditorVariant variant, {
  VoidCallback? onPressed,
  Color? background,
}) async {
  await pumpApp(
    tester,
    Builder(
      builder: (context) => CardIconButton(
        tooltip: 'Закрыть',
        icon: LucideIcons.x,
        style: CardEditorStyle.of(context, variant),
        foreground: CardoColors.of(context).textPrimary,
        background: background,
        onPressed: onPressed,
      ),
    ),
  );
}

BoxDecoration _chipDecoration(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.descendant(
      of: find.byType(CardColumnChip),
      matching: find.byType(Container),
    ),
  );
  return container.decoration! as BoxDecoration;
}

OutlinedBorder _buttonShape(WidgetTester tester) {
  final button = tester.widget<IconButton>(find.byType(IconButton));
  return button.style!.shape!.resolve(<WidgetState>{})!;
}

void main() {
  group('CardColumnChip', () {
    testWidgets('sheet variant is 30 high with radius 9', (tester) async {
      await _pumpChip(tester, CardEditorVariant.sheet);
      expect(tester.getSize(find.byType(CardColumnChip)).height, 30);
      final decoration = _chipDecoration(tester);
      expect(decoration.borderRadius, BorderRadius.circular(9));
      expect(decoration.border, isNull);
      final context = tester.element(find.byType(CardColumnChip));
      expect(decoration.color, CardoColors.of(context).background);
      final marker = tester.widget<ColumnMarkerSquare>(
        find.byType(ColumnMarkerSquare),
      );
      expect(marker.size, CardoLayout.of(context).markerColumnDense);
      expect(find.text('В работе'), findsOneWidget);
    });

    testWidgets('panel variant keeps its previous look', (tester) async {
      await _pumpChip(tester, CardEditorVariant.panel);
      final context = tester.element(find.byType(CardColumnChip));
      expect(tester.getSize(find.byType(CardColumnChip)).height, 28);
      final decoration = _chipDecoration(tester);
      expect(decoration.borderRadius, BorderRadius.circular(8));
      expect(decoration.color, CardoColors.of(context).card);
      final border = decoration.border! as Border;
      expect(border.top.color, CardoColors.of(context).cardBorder);
      expect(border.top.width, CardoSizes.of(context).hairline);
      final marker = tester.widget<ColumnMarkerSquare>(
        find.byType(ColumnMarkerSquare),
      );
      expect(marker.size, CardoSizes.of(context).markerTab);
      expect(find.text('В работе'), findsOneWidget);
    });

    testWidgets('grows with the text scale instead of clipping', (
      tester,
    ) async {
      await _pumpChip(tester, CardEditorVariant.sheet, textScale: 2);
      expect(
        tester.getSize(find.byType(CardColumnChip)).height,
        greaterThanOrEqualTo(30),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the sheet and panel chips have different heights', (
      tester,
    ) async {
      await _pumpChip(tester, CardEditorVariant.sheet);
      final sheetHeight = tester.getSize(find.byType(CardColumnChip)).height;
      await _pumpChip(tester, CardEditorVariant.panel);
      final panelHeight = tester.getSize(find.byType(CardColumnChip)).height;
      expect(sheetHeight, isNot(panelHeight));
    });
  });

  group('CardIconButton', () {
    testWidgets('sheet variant is 44 by 44 with the sheet radius', (
      tester,
    ) async {
      await _pumpButton(tester, CardEditorVariant.sheet, onPressed: () {});
      expect(tester.getSize(find.byTooltip('Закрыть')), const Size(44, 44));
      final shape = _buttonShape(tester) as RoundedRectangleBorder;
      final context = tester.element(find.byType(IconButton));
      expect(
        shape.borderRadius,
        BorderRadius.circular(CardoRadii.of(context).iconButton),
      );
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, LucideIcons.x);
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).iconSize,
        CardoSizes.of(context).iconLarge,
      );
    });

    testWidgets('panel variant keeps its previous radius and icon size', (
      tester,
    ) async {
      await _pumpButton(tester, CardEditorVariant.panel, onPressed: () {});
      final context = tester.element(find.byType(IconButton));
      final shape = _buttonShape(tester) as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(10));
      expect(
        shape.borderRadius,
        BorderRadius.circular(CardoRadii.of(context).buttonSmall),
      );
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).iconSize,
        CardoSizes.of(context).iconButton,
      );
    });

    for (final variant in CardEditorVariant.values) {
      testWidgets('${variant.name} tap area is at least 44 by 44', (
        tester,
      ) async {
        await _pumpButton(tester, variant, onPressed: () {});
        final size = tester.getSize(find.byType(IconButton));
        expect(size.width, greaterThanOrEqualTo(44));
        expect(size.height, greaterThanOrEqualTo(44));
      });

      testWidgets('${variant.name} reacts to a tap at its corner', (
        tester,
      ) async {
        var taps = 0;
        await _pumpButton(tester, variant, onPressed: () => taps++);
        final rect = tester.getRect(find.byType(IconButton));
        await tester.tapAt(rect.topLeft + const Offset(2, 2));
        await tester.tapAt(rect.bottomRight - const Offset(2, 2));
        expect(taps, 2);
      });

      testWidgets('${variant.name} is a labelled button for screen readers', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await _pumpButton(tester, variant, onPressed: () {});
        final node = tester.getSemantics(find.byType(IconButton));
        expect(node.tooltip, 'Закрыть');
        expect(node.flagsCollection.isButton, isTrue);
        expect(node.flagsCollection.isEnabled, Tristate.isTrue);
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        handle.dispose();
      });

      testWidgets('${variant.name} stays labelled but inert when disabled', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await _pumpButton(tester, variant);
        final node = tester.getSemantics(find.byType(IconButton));
        expect(node.tooltip, 'Закрыть');
        expect(node.flagsCollection.isEnabled, Tristate.isFalse);
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
        expect(
          tester.widget<IconButton>(find.byType(IconButton)).onPressed,
          isNull,
        );
        handle.dispose();
      });
    }

    testWidgets('uses the given background and foreground', (tester) async {
      const background = Color(0xFF123456);
      await _pumpButton(
        tester,
        CardEditorVariant.sheet,
        onPressed: () {},
        background: background,
      );
      final style = tester.widget<IconButton>(find.byType(IconButton)).style!;
      expect(style.backgroundColor!.resolve(<WidgetState>{}), background);
      final context = tester.element(find.byType(IconButton));
      expect(
        style.foregroundColor!.resolve(<WidgetState>{}),
        CardoColors.of(context).textPrimary,
      );
    });
  });
}
