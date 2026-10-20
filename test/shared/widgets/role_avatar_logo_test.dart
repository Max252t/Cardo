import 'dart:ui' as ui;

import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/l10n/app_localizations.dart';
import 'package:cardo/shared/widgets/avatar_identity.dart';
import 'package:cardo/shared/widgets/avatar_stack.dart';
import 'package:cardo/shared/widgets/cardo_avatar.dart';
import 'package:cardo/shared/widgets/cardo_logo.dart';
import 'package:cardo/shared/widgets/role_badge.dart';
import 'package:cardo/theme/cardo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../helpers/pump_app.dart';

const _people = <AvatarIdentity>[
  AvatarIdentity(name: 'Аня', colorHex: '#7C4DEB'),
  AvatarIdentity(name: 'Максим', colorHex: '#2D68F5'),
  AvatarIdentity(name: 'Елена', colorHex: '#13804F'),
  AvatarIdentity(name: 'Ольга', colorHex: '#D23A6E'),
  AvatarIdentity(name: 'Дмитрий', colorHex: '#F2A516'),
  AvatarIdentity(name: 'Борис', colorHex: 'broken'),
];

const _first = AvatarIdentity(name: 'Аня', colorHex: '#7C4DEB');
const _last = AvatarIdentity(name: 'Борис', colorHex: 'broken');

Finder _eye() => find.byWidgetPredicate(
  (w) => w is Icon && w.icon == LucideIcons.eye,
  skipOffstage: false,
);

void main() {
  group('AvatarIdentity', () {
    test('initial is uppercase first letter', () {
      expect(
        const AvatarIdentity(name: 'аня', colorHex: '#000000').initial,
        'А',
      );
    });

    test('initial trims whitespace', () {
      expect(
        const AvatarIdentity(name: '  Макс', colorHex: '#000000').initial,
        'М',
      );
    });

    test('initial of empty name is empty', () {
      expect(const AvatarIdentity(name: ' ', colorHex: '#000000').initial, '');
    });

    test('equality', () {
      const a = AvatarIdentity(name: 'Аня', colorHex: '#000000');
      const b = AvatarIdentity(name: 'Аня', colorHex: '#000000');
      const c = AvatarIdentity(name: 'Аня', colorHex: '#111111');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });
  });

  for (final brightness in Brightness.values) {
    group('RoleBadge ${brightness.name}', () {
      testWidgets('owner', (tester) async {
        await pumpApp(
          tester,
          const RoleBadge(role: BoardRole.owner),
          brightness: brightness,
        );
        expect(find.text('Владелец'), findsOneWidget);
        expect(_eye(), findsNothing);
      });

      testWidgets('editor', (tester) async {
        await pumpApp(
          tester,
          const RoleBadge(role: BoardRole.editor),
          brightness: brightness,
        );
        expect(find.text('Редактор'), findsOneWidget);
        expect(_eye(), findsNothing);
      });

      testWidgets('viewer has eye icon', (tester) async {
        await pumpApp(
          tester,
          const RoleBadge(role: BoardRole.viewer),
          brightness: brightness,
        );
        expect(find.text('Наблюдатель'), findsOneWidget);
        expect(_eye(), findsOneWidget);
      });

      testWidgets('height is at least 28', (tester) async {
        await pumpApp(
          tester,
          const RoleBadge(role: BoardRole.owner),
          brightness: brightness,
        );
        expect(
          tester.getSize(find.byType(RoleBadge)).height,
          greaterThanOrEqualTo(28),
        );
      });
    });
  }

  group('RoleBadge details', () {
    testWidgets('editor has outline, owner and viewer do not', (tester) async {
      BoxDecoration decorationOf(WidgetTester tester) {
        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(RoleBadge),
            matching: find.byType(Container),
          ),
        );
        return container.decoration as BoxDecoration;
      }

      await pumpApp(tester, const RoleBadge(role: BoardRole.editor));
      expect(decorationOf(tester).border, isNotNull);
      await pumpApp(tester, const RoleBadge(role: BoardRole.owner));
      expect(decorationOf(tester).border, isNull);
      expect(decorationOf(tester).color, CardoColors.light.emphasis);
      await pumpApp(tester, const RoleBadge(role: BoardRole.viewer));
      expect(
        decorationOf(tester).color,
        CardoColors.light.roleViewerBackground,
      );
    });

    testWidgets('labelFor covers every role', (tester) async {
      late BuildContext captured;
      await pumpApp(
        tester,
        Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      );
      final l10n = AppLocalizations.of(captured);
      expect(RoleBadge.labelFor(l10n, BoardRole.owner), 'Владелец');
      expect(RoleBadge.labelFor(l10n, BoardRole.editor), 'Редактор');
      expect(RoleBadge.labelFor(l10n, BoardRole.viewer), 'Наблюдатель');
    });

    testWidgets('semantics label', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, const RoleBadge(role: BoardRole.viewer));
      expect(find.bySemanticsLabel('Роль: Наблюдатель'), findsOneWidget);
      handle.dispose();
    });
  });

  group('CardoAvatar', () {
    testWidgets('shows initial and semantic name', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, const CardoAvatar(identity: _first, diameter: 36));
      expect(find.text('А'), findsOneWidget);
      expect(find.bySemanticsLabel('Аня'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('custom semantic label wins', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        const CardoAvatar(
          identity: _first,
          diameter: 36,
          semanticLabel: 'Изменил Аня',
        ),
      );
      expect(find.bySemanticsLabel('Изменил Аня'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('fill follows the identity color', (tester) async {
      await pumpApp(tester, const CardoAvatar(identity: _first, diameter: 36));
      final circle = tester.widget<AvatarCircle>(find.byType(AvatarCircle));
      expect(circle.fill, const Color(0xFF7C4DEB));
    });

    testWidgets('broken color uses fallback', (tester) async {
      await pumpApp(tester, const CardoAvatar(identity: _last, diameter: 36));
      final circle = tester.widget<AvatarCircle>(find.byType(AvatarCircle));
      expect(circle.fill, CardoColors.light.avatarFallback);
    });

    testWidgets('has the requested diameter', (tester) async {
      await pumpApp(tester, const CardoAvatar(identity: _first, diameter: 30));
      expect(tester.getSize(find.byType(AvatarCircle)), const Size(30, 30));
    });
  });

  group('AvatarStack', () {
    Widget stack({int count = 3, int maxVisible = 4}) {
      return AvatarStack(
        people: _people.take(count).toList(),
        diameter: 28,
        overlap: 8,
        ringWidth: 2,
        maxVisible: maxVisible,
      );
    }

    testWidgets('empty list renders nothing', (tester) async {
      await pumpApp(
        tester,
        const AvatarStack(
          people: <AvatarIdentity>[],
          diameter: 28,
          overlap: 8,
          ringWidth: 2,
        ),
      );
      expect(find.byType(CardoAvatar), findsNothing);
    });

    testWidgets('shows all when within maxVisible', (tester) async {
      await pumpApp(tester, stack(count: 3));
      expect(find.byType(CardoAvatar), findsNWidgets(3));
      expect(find.byType(AvatarOverflowBubble), findsNothing);
      expect(find.text('А'), findsOneWidget);
      expect(find.text('М'), findsOneWidget);
      expect(find.text('Е'), findsOneWidget);
    });

    testWidgets('exactly maxVisible has no bubble', (tester) async {
      await pumpApp(tester, stack(count: 4));
      expect(find.byType(CardoAvatar), findsNWidgets(4));
      expect(find.byType(AvatarOverflowBubble), findsNothing);
    });

    testWidgets('overflow shows plus N bubble', (tester) async {
      await pumpApp(tester, stack(count: 6));
      expect(find.byType(CardoAvatar), findsNWidgets(4));
      expect(find.byType(AvatarOverflowBubble), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('custom maxVisible', (tester) async {
      await pumpApp(tester, stack(count: 5, maxVisible: 2));
      expect(find.byType(CardoAvatar), findsNWidgets(2));
      expect(find.text('+3'), findsOneWidget);
    });

    testWidgets('width accounts for overlap', (tester) async {
      await pumpApp(tester, stack(count: 3));
      expect(tester.getSize(find.byType(AvatarStack)).width, 28 + (28 - 8) * 2);
      expect(tester.getSize(find.byType(AvatarStack)).height, 28);
    });

    testWidgets('width includes overflow bubble', (tester) async {
      await pumpApp(tester, stack(count: 6));
      expect(tester.getSize(find.byType(AvatarStack)).width, 28 + (28 - 8) * 4);
    });

    testWidgets('ring defaults to theme background', (tester) async {
      await pumpApp(tester, stack(count: 2), brightness: Brightness.dark);
      final circle = tester
          .widgetList<AvatarCircle>(find.byType(AvatarCircle))
          .first;
      expect(circle.ringColor, CardoColors.dark.background);
      expect(circle.ringWidth, 2);
    });

    testWidgets('overlap larger than diameter does not go negative', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const AvatarStack(
          people: _people,
          diameter: 28,
          overlap: 40,
          ringWidth: 2,
        ),
      );
      expect(tester.getSize(find.byType(AvatarStack)).width, 28);
    });

    testWidgets('semantics reports member count with plural', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, stack(count: 3));
      expect(find.bySemanticsLabel('3 участника на доске'), findsOneWidget);
      await pumpApp(tester, stack(count: 6));
      expect(find.bySemanticsLabel('6 участников на доске'), findsOneWidget);
      await pumpApp(tester, stack(count: 1));
      expect(
        tester.getSemantics(find.byType(AvatarStack)).label,
        startsWith('1 участник на доске'),
      );
      handle.dispose();
    });

    testWidgets('overflow bubble colors follow theme', (tester) async {
      await pumpApp(tester, stack(count: 6), brightness: Brightness.dark);
      final bubble = tester.widget<AvatarCircle>(
        find.descendant(
          of: find.byType(AvatarOverflowBubble),
          matching: find.byType(AvatarCircle),
        ),
      );
      expect(bubble.fill, CardoColors.dark.avatarOverflowBackground);
    });
  });

  group('CardoLogo', () {
    CardoLogoPainter painterOf(WidgetTester tester) {
      final paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(CardoLogo),
          matching: find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is CardoLogoPainter,
          ),
        ),
      );
      return paint.painter! as CardoLogoPainter;
    }

    testWidgets('renders mark and wordmark', (tester) async {
      await pumpApp(tester, const CardoLogo());
      expect(find.text('cardo'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is CardoLogoPainter,
        ),
        findsOneWidget,
      );
    });

    testWidgets('can hide wordmark', (tester) async {
      await pumpApp(tester, const CardoLogo(showWordmark: false));
      expect(find.text('cardo'), findsNothing);
    });

    testWidgets('large mark is bigger', (tester) async {
      await pumpApp(tester, const CardoLogo());
      final regular = tester
          .widget<CustomPaint>(
            find.byWidgetPredicate(
              (w) => w is CustomPaint && w.painter is CardoLogoPainter,
            ),
          )
          .size;
      await pumpApp(tester, const CardoLogo(size: CardoLogoSize.large));
      final large = tester
          .widget<CustomPaint>(
            find.byWidgetPredicate(
              (w) => w is CustomPaint && w.painter is CardoLogoPainter,
            ),
          )
          .size;
      expect(large.width, greaterThan(regular.width));
    });

    testWidgets('painter colors come from theme in both modes', (tester) async {
      await pumpApp(tester, const CardoLogo());
      expect(painterOf(tester).backColor, CardoColors.light.textPrimary);
      expect(painterOf(tester).frontColor, CardoColors.light.accent);
      await pumpApp(tester, const CardoLogo(), brightness: Brightness.dark);
      expect(painterOf(tester).backColor, CardoColors.dark.textPrimary);
      expect(painterOf(tester).frontColor, CardoColors.dark.accent);
    });

    testWidgets('semantics label', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, const CardoLogo());
      expect(find.bySemanticsLabel('Логотип cardo'), findsOneWidget);
      handle.dispose();
    });

    test('shouldRepaint compares colors', () {
      const base = CardoLogoPainter(
        backColor: Color(0xFF000000),
        frontColor: Color(0xFFFF0000),
      );
      expect(
        base.shouldRepaint(
          const CardoLogoPainter(
            backColor: Color(0xFF000000),
            frontColor: Color(0xFFFF0000),
          ),
        ),
        isFalse,
      );
      expect(
        base.shouldRepaint(
          const CardoLogoPainter(
            backColor: Color(0xFF111111),
            frontColor: Color(0xFFFF0000),
          ),
        ),
        isTrue,
      );
      expect(
        base.shouldRepaint(
          const CardoLogoPainter(
            backColor: Color(0xFF000000),
            frontColor: Color(0xFF00FF00),
          ),
        ),
        isTrue,
      );
    });

    test('painter draws without throwing', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const CardoLogoPainter(
        backColor: Color(0xFF000000),
        frontColor: Color(0xFFFF0000),
      ).paint(canvas, const Size(32, 32));
      recorder.endRecording().dispose();
    });

    test('scaleRect scales every edge', () {
      final scaled = CardoLogoPainter.scaleRect(
        const Rect.fromLTWH(1, 2, 3, 4),
        2,
      );
      expect(scaled, const Rect.fromLTWH(2, 4, 6, 8));
    });
  });
}
