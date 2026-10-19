import 'package:cardo/shared/widgets/avatar_identity.dart';
import 'package:cardo/shared/widgets/card_tile.dart';
import 'package:cardo/shared/widgets/dashed_border.dart';
import 'package:cardo/theme/cardo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../helpers/pump_app.dart';

const _anya = AvatarIdentity(name: 'Аня', colorHex: '#7C4DEB');
const _maxim = AvatarIdentity(name: 'Максим', colorHex: '#2D68F5');
const _longName = AvatarIdentity(
  name: 'Константин Константинопольский',
  colorHex: '#7C4DEB',
);

Finder _icon(IconData data) {
  return find.byWidgetPredicate(
    (widget) => widget is Icon && widget.icon == data,
    skipOffstage: false,
  );
}

TextStyle _style(WidgetTester tester, String text) {
  return tester.widget<Text>(find.text(text)).style!;
}

bool _hasRotation(WidgetTester tester) {
  final transforms = tester.widgetList<Transform>(
    find.descendant(
      of: find.byType(CardTile),
      matching: find.byType(Transform),
    ),
  );
  return transforms.any((transform) {
    final m = transform.transform.storage;
    return m[1].abs() > 0.0001 || m[4].abs() > 0.0001;
  });
}

void main() {
  for (final brightness in Brightness.values) {
    group('CardTile ${brightness.name}', () {
      testWidgets('confirmed shows only title', (tester) async {
        await pumpApp(
          tester,
          const CardTile(title: 'Fractional indexing'),
          brightness: brightness,
        );
        expect(find.text('Fractional indexing'), findsOneWidget);
        expect(find.text('Описание'), findsNothing);
        expect(find.text('В очереди'), findsNothing);
        expect(find.text('Перемещение'), findsNothing);
        expect(find.text('Не применено'), findsNothing);
      });

      testWidgets('confirmed with description shows footer', (tester) async {
        await pumpApp(
          tester,
          const CardTile(title: 'Задача', hasDescription: true),
          brightness: brightness,
        );
        expect(find.text('Описание'), findsOneWidget);
        expect(_icon(LucideIcons.textAlignStart), findsOneWidget);
      });

      testWidgets('pending shows clock and queue label', (tester) async {
        await pumpApp(
          tester,
          const CardTile(title: 'Задача', state: CardTileState.pending),
          brightness: brightness,
        );
        expect(find.text('В очереди'), findsOneWidget);
        expect(_icon(LucideIcons.clock), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(CardTile),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is CustomPaint &&
                  w.foregroundPainter is DashedBorderPainter,
            ),
          ),
          findsOneWidget,
        );
      });

      testWidgets('dragging shows move icon and label', (tester) async {
        await pumpApp(
          tester,
          const CardTile(title: 'Задача', state: CardTileState.dragging),
          brightness: brightness,
        );
        expect(find.text('Перемещение'), findsOneWidget);
        expect(_icon(LucideIcons.move), findsOneWidget);
      });

      testWidgets('rejected has strikethrough, icon and reason', (
        tester,
      ) async {
        await pumpApp(
          tester,
          const CardTile(
            title: 'Задача',
            state: CardTileState.rejected,
            rejectReason: 'Карточку уже переместил Максим',
          ),
          brightness: brightness,
        );
        expect(_style(tester, 'Задача').decoration, TextDecoration.lineThrough);
        expect(find.text('Не применено'), findsOneWidget);
        expect(_icon(LucideIcons.circleAlert), findsOneWidget);
        expect(find.text('Карточку уже переместил Максим'), findsOneWidget);
        final colors = brightness == Brightness.light
            ? CardoColors.light
            : CardoColors.dark;
        expect(
          _style(tester, 'Карточку уже переместил Максим').color,
          colors.nackText,
        );
      });

      testWidgets('non-rejected titles are not struck through', (tester) async {
        for (final state in <CardTileState>[
          CardTileState.confirmed,
          CardTileState.pending,
          CardTileState.dragging,
        ]) {
          await pumpApp(
            tester,
            CardTile(title: 'Задача', state: state),
            brightness: brightness,
          );
          expect(
            _style(tester, 'Задача').decoration,
            isNot(TextDecoration.lineThrough),
          );
        }
      });

      testWidgets('rejected without reason shows no reason text', (
        tester,
      ) async {
        await pumpApp(
          tester,
          const CardTile(title: 'Задача', state: CardTileState.rejected),
          brightness: brightness,
        );
        expect(find.text('Не применено'), findsOneWidget);
        final texts = tester
            .widgetList<Text>(
              find.descendant(
                of: find.byType(CardTile),
                matching: find.byType(Text),
              ),
            )
            .map((text) => text.data ?? text.textSpan?.toPlainText())
            .toList();
        expect(texts, unorderedEquals(<String>['Задача', 'Не применено']));
      });
    });
  }

  group('CardTile editing tag', () {
    testWidgets('shows full label', (tester) async {
      await pumpApp(tester, const CardTile(title: 'Задача', editingBy: _anya));
      expect(find.text('Аня редактирует'), findsOneWidget);
    });

    for (final textScale in <double>[1.0, 1.3, 2.0]) {
      for (final dense in <bool>[false, true]) {
        testWidgets(
          'long name stays inside card and off the title at scale $textScale dense $dense',
          (tester) async {
            const title = 'Экран доски только на чтение';
            await pumpApp(
              tester,
              SizedBox(
                width: 318,
                child: CardTile(
                  title: title,
                  editingBy: _longName,
                  dense: dense,
                ),
              ),
              textScale: textScale,
            );
            expect(tester.takeException(), isNull);
            final card = tester.getRect(find.byType(CardTileSurface));
            final tag = tester.getRect(find.byType(CardEditingTagLabel));
            final titleRect = tester.getRect(find.text(title));
            expect(tag.left, greaterThanOrEqualTo(0));
            expect(tag.left, greaterThanOrEqualTo(card.left));
            expect(tag.right, lessThanOrEqualTo(card.right));
            expect(tag.overlaps(titleRect), isFalse);
          },
        );
      }
    }

    testWidgets('short name floats over the top edge at default scale', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const SizedBox(
          width: 318,
          child: CardTile(title: 'Задача', editingBy: _anya),
        ),
      );
      expect(find.byType(CardEditingTag), findsOneWidget);
      final card = tester.getRect(find.byType(CardTileSurface));
      final tag = tester.getRect(find.byType(CardEditingTagLabel));
      expect(tag.top, lessThan(card.top));
      expect(tag.overlaps(tester.getRect(find.text('Задача'))), isFalse);
    });

    testWidgets('long name at large scale moves into the content flow', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const SizedBox(
          width: 318,
          child: CardTile(title: 'Задача', editingBy: _longName),
        ),
        textScale: 2.0,
      );
      expect(find.byType(CardEditingTag), findsNothing);
      expect(find.byType(CardEditingTagLabel), findsOneWidget);
      final card = tester.getRect(find.byType(CardTileSurface));
      final tag = tester.getRect(find.byType(CardEditingTagLabel));
      expect(tag.top, greaterThanOrEqualTo(card.top));
    });

    testWidgets('dense shows name only', (tester) async {
      await pumpApp(
        tester,
        const CardTile(title: 'Задача', editingBy: _anya, dense: true),
      );
      expect(find.text('Аня'), findsOneWidget);
      expect(find.text('Аня редактирует'), findsNothing);
    });

    testWidgets('hidden when rejected', (tester) async {
      await pumpApp(
        tester,
        const CardTile(
          title: 'Задача',
          editingBy: _anya,
          state: CardTileState.rejected,
        ),
      );
      expect(find.text('Аня редактирует'), findsNothing);
    });

    testWidgets('absent without editor', (tester) async {
      await pumpApp(tester, const CardTile(title: 'Задача'));
      expect(find.byType(CardEditingTag), findsNothing);
    });

    testWidgets('tag uses avatar accent in dark theme', (tester) async {
      await pumpApp(
        tester,
        const CardTile(title: 'Задача', editingBy: _anya),
        brightness: Brightness.dark,
      );
      final decorated = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(CardEditingTag),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = decorated.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFF9B7BFF));
    });

    testWidgets('border uses avatar accent', (tester) async {
      await pumpApp(tester, const CardTile(title: 'Задача', editingBy: _anya));
      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final decoration = container.decoration as BoxDecoration;
      expect((decoration.border as Border).top.color, const Color(0xFF7C4DEB));
    });
  });

  group('CardTile footer', () {
    testWidgets('shows updatedBy avatar initial', (tester) async {
      await pumpApp(tester, const CardTile(title: 'Задача', updatedBy: _maxim));
      expect(find.text('М'), findsOneWidget);
    });

    testWidgets('description and avatar together', (tester) async {
      await pumpApp(
        tester,
        const CardTile(
          title: 'Задача',
          hasDescription: true,
          updatedBy: _maxim,
        ),
      );
      expect(find.text('Описание'), findsOneWidget);
      expect(find.text('М'), findsOneWidget);
    });

    testWidgets('no footer without status or author', (tester) async {
      await pumpApp(tester, const CardTile(title: 'Задача'));
      expect(find.byType(CardTileFooter), findsNothing);
    });
  });

  group('CardTile interaction', () {
    testWidgets('onTap fires', (tester) async {
      var taps = 0;
      await pumpApp(tester, CardTile(title: 'Задача', onTap: () => taps++));
      await tester.tap(find.text('Задача'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('tap target is at least 44 high', (tester) async {
      await pumpApp(tester, const CardTile(title: 'Я'));
      final size = tester.getSize(find.byType(CardTileSurface));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('dense uses smaller radius', (tester) async {
      await pumpApp(tester, const CardTile(title: 'Задача'));
      var decoration =
          tester
                  .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                  .decoration
              as BoxDecoration;
      expect(
        decoration.borderRadius,
        BorderRadius.circular(CardoRadii.standard.card),
      );
      await pumpApp(tester, const CardTile(title: 'Задача', dense: true));
      decoration =
          tester
                  .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                  .decoration
              as BoxDecoration;
      expect(
        decoration.borderRadius,
        BorderRadius.circular(CardoRadii.standard.cardDense),
      );
    });
  });

  group('CardTile reduce motion', () {
    testWidgets('dragging rotates without the flag', (tester) async {
      await pumpApp(
        tester,
        const CardTile(title: 'Задача', state: CardTileState.dragging),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final rotation = tester.widget<AnimatedRotation>(
        find.byType(AnimatedRotation),
      );
      expect(rotation.turns, CardoMotion.standard.dragTiltTurns);
      expect(_hasRotation(tester), isTrue);
      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, CardoMotion.standard.dragScale);
    });

    testWidgets('dragging does not rotate with disableAnimations', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const CardTile(title: 'Задача', state: CardTileState.dragging),
        disableAnimations: true,
      );
      await tester.pump(const Duration(milliseconds: 400));
      final rotation = tester.widget<AnimatedRotation>(
        find.byType(AnimatedRotation),
      );
      expect(rotation.turns, 0);
      expect(rotation.duration, Duration.zero);
      expect(_hasRotation(tester), isFalse);
      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, 1);
    });

    testWidgets('confirmed never rotates', (tester) async {
      await pumpApp(tester, const CardTile(title: 'Задача'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_hasRotation(tester), isFalse);
    });

    testWidgets('state change to dragging animates tilt', (tester) async {
      Widget build(CardTileState state) => wrapApp(
        Center(
          child: CardTile(title: 'Задача', state: state),
        ),
      );
      await tester.pumpWidget(build(CardTileState.confirmed));
      expect(_hasRotation(tester), isFalse);
      await tester.pumpWidget(build(CardTileState.dragging));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_hasRotation(tester), isTrue);
    });
  });

  group('CardTile semantics', () {
    testWidgets('merges title and status into one node', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        const CardTile(
          title: 'Fractional indexing',
          state: CardTileState.pending,
        ),
      );
      final node = tester.getSemantics(find.byType(CardTile));
      expect(node.label, contains('Fractional indexing'));
      expect(node.label, contains('В очереди'));
      handle.dispose();
    });

    testWidgets('rejected exposes reason to screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        const CardTile(
          title: 'Задача',
          state: CardTileState.rejected,
          rejectReason: 'Карточку уже переместил Максим',
        ),
      );
      final node = tester.getSemantics(find.byType(CardTile));
      expect(node.label, contains('Не применено'));
      expect(node.label, contains('Карточку уже переместил Максим'));
      handle.dispose();
    });

    testWidgets('editing label is available', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, const CardTile(title: 'Задача', editingBy: _anya));
      final node = tester.getSemantics(find.byType(CardTile));
      expect(node.label, contains('Аня редактирует'));
      handle.dispose();
    });

    testWidgets('updated by label is available', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, const CardTile(title: 'Задача', updatedBy: _maxim));
      expect(find.bySemanticsLabel(RegExp('Изменил Максим')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('tappable tile exposes tap action', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, CardTile(title: 'Задача', onTap: () {}));
      final node = tester.getSemantics(find.byType(CardTile));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });
  });

  group('CardDropPlaceholder', () {
    testWidgets('renders with semantic label', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, const CardDropPlaceholder());
      expect(find.bySemanticsLabel('Место для карточки'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('dense is shorter or equal', (tester) async {
      await pumpApp(tester, const CardDropPlaceholder());
      final regular = tester.getSize(find.byType(CardDropPlaceholder)).height;
      await pumpApp(tester, const CardDropPlaceholder(dense: true));
      final dense = tester.getSize(find.byType(CardDropPlaceholder)).height;
      expect(dense, lessThanOrEqualTo(regular));
    });
  });
}
