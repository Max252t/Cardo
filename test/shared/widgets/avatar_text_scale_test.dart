import 'package:cardo/shared/widgets/avatar_identity.dart';
import 'package:cardo/shared/widgets/avatar_stack.dart';
import 'package:cardo/shared/widgets/cardo_avatar.dart';
import 'package:cardo/theme/cardo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

const AvatarIdentity _elena = AvatarIdentity(
  name: 'Елена',
  colorHex: '#2D68F5',
);

const List<double> _diameters = <double>[22, 30, 34, 36];

Widget _avatar(double diameter) {
  return CardoAvatar(identity: _elena, diameter: diameter, ringWidth: 2);
}

Widget _bubble(double diameter) {
  return AvatarOverflowBubble(
    count: 3,
    diameter: diameter,
    ringWidth: 2,
    ringColor: Colors.transparent,
  );
}

Future<Rect> _glyphBox(
  WidgetTester tester,
  Widget child,
  String text, {
  required double scale,
  required Brightness brightness,
}) async {
  await pumpApp(tester, child, brightness: brightness, textScale: scale);
  return tester.getRect(find.text(text));
}

double _effectiveFontSize(WidgetTester tester, String text) {
  final paragraph = tester.widget<RichText>(
    find.descendant(of: find.text(text), matching: find.byType(RichText)),
  );
  return paragraph.textScaler.scale(paragraph.text.style!.fontSize!);
}

void main() {
  for (final brightness in Brightness.values) {
    for (final diameter in _diameters) {
      for (final scale in <double>[1.5, 2.0, 3.0]) {
        testWidgets('CardoAvatar $diameter initial ignores text scale x$scale '
            '(${brightness.name})', (tester) async {
          final base = await _glyphBox(
            tester,
            _avatar(diameter),
            'Е',
            scale: 1,
            brightness: brightness,
          );
          final scaled = await _glyphBox(
            tester,
            _avatar(diameter),
            'Е',
            scale: scale,
            brightness: brightness,
          );
          expect(scaled.size, base.size);
          expect(scaled.center, base.center);
          expect(tester.takeException(), isNull);
        });

        testWidgets(
          'overflow bubble $diameter label ignores text scale x$scale '
          '(${brightness.name})',
          (tester) async {
            final base = await _glyphBox(
              tester,
              _bubble(diameter),
              '+3',
              scale: 1,
              brightness: brightness,
            );
            final scaled = await _glyphBox(
              tester,
              _bubble(diameter),
              '+3',
              scale: scale,
              brightness: brightness,
            );
            expect(scaled.size, base.size);
            expect(scaled.center, base.center);
          },
        );
      }
    }
  }

  testWidgets('initial uses the exact font size from the table at scale 2', (
    tester,
  ) async {
    final expected = <double, double>{22: 11, 30: 12, 34: 13, 36: 14};
    for (final entry in expected.entries) {
      await pumpApp(tester, _avatar(entry.key), textScale: 2);
      expect(_effectiveFontSize(tester, 'Е'), entry.value);
    }
  });

  testWidgets('glyph box fits inside the ring at scale 2', (tester) async {
    for (final diameter in _diameters) {
      await pumpApp(tester, _avatar(diameter), textScale: 2);
      final circle = tester.getRect(find.byType(AvatarCircle));
      final glyph = tester.getRect(find.text('Е'));
      final inner = circle.deflate(2);
      expect(glyph.width, lessThanOrEqualTo(inner.width));
      expect(glyph.height, lessThanOrEqualTo(inner.height));
    }
  });

  testWidgets('avatar size does not grow with text scale', (tester) async {
    await pumpApp(tester, _avatar(30), textScale: 2);
    expect(tester.getSize(find.byType(AvatarCircle)), const Size(30, 30));
  });

  testWidgets('name stays available to screen readers at scale 2', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, _avatar(30), textScale: 2);
    expect(find.bySemanticsLabel('Елена'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('theme table is what the avatar reads', (tester) async {
    await pumpApp(tester, _avatar(30));
    final typography = CardoTypography.of(
      tester.element(find.byType(CardoAvatar)),
    );
    expect(typography.avatarInitialSize(30), 12);
  });
}
