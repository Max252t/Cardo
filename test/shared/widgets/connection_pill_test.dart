import 'package:cardo/core/realtime/connection_status.dart';
import 'package:cardo/shared/widgets/connection_pill.dart';
import 'package:cardo/theme/cardo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../helpers/pump_app.dart';

const _labels = <ConnectionStatus, String>{
  ConnectionStatus.connected: 'В сети',
  ConnectionStatus.syncing: 'Синхронизация',
  ConnectionStatus.reconnecting: 'Переподключение',
  ConnectionStatus.offline: 'Офлайн',
};

String _glyphKind(WidgetTester tester) {
  final glyph = find.byType(ConnectionGlyph);
  final icon = find.descendant(of: glyph, matching: find.byType(Icon));
  if (icon.evaluate().isNotEmpty) {
    return 'icon:${tester.widget<Icon>(icon).icon!.codePoint}';
  }
  final container = tester.widget<Container>(
    find.descendant(of: glyph, matching: find.byType(Container)),
  );
  final decoration = container.decoration as BoxDecoration;
  return decoration.border == null ? 'dot' : 'ring';
}

void main() {
  for (final brightness in Brightness.values) {
    for (final variant in ConnectionPillVariant.values) {
      group('ConnectionPill ${brightness.name} ${variant.name}', () {
        for (final status in ConnectionStatus.values) {
          testWidgets('${status.name} renders label', (tester) async {
            await pumpApp(
              tester,
              ConnectionPill(status: status, variant: variant),
              brightness: brightness,
            );
            expect(find.text(_labels[status]!), findsOneWidget);
          });
        }

        testWidgets('reconnecting shows seconds', (tester) async {
          await pumpApp(
            tester,
            ConnectionPill(
              status: ConnectionStatus.reconnecting,
              reconnectSeconds: 4,
              variant: variant,
            ),
            brightness: brightness,
          );
          expect(find.text('Переподключение · 4 с'), findsOneWidget);
        });

        testWidgets('each status has a different glyph', (tester) async {
          final kinds = <String>{};
          for (final status in ConnectionStatus.values) {
            await pumpApp(
              tester,
              ConnectionPill(status: status, variant: variant),
              brightness: brightness,
            );
            kinds.add(_glyphKind(tester));
          }
          expect(kinds.length, ConnectionStatus.values.length);
        });
      });
    }
  }

  group('ConnectionPill glyphs', () {
    testWidgets('syncing uses refresh icon', (tester) async {
      await pumpApp(
        tester,
        const ConnectionPill(status: ConnectionStatus.syncing),
      );
      expect(_glyphKind(tester), 'icon:${LucideIcons.refreshCw.codePoint}');
    });

    testWidgets('offline uses wifi-off icon', (tester) async {
      await pumpApp(
        tester,
        const ConnectionPill(status: ConnectionStatus.offline),
      );
      expect(_glyphKind(tester), 'icon:${LucideIcons.wifiOff.codePoint}');
    });

    testWidgets('connected is a dot and reconnecting a ring', (tester) async {
      await pumpApp(
        tester,
        const ConnectionPill(status: ConnectionStatus.connected),
      );
      expect(_glyphKind(tester), 'dot');
      await pumpApp(
        tester,
        const ConnectionPill(status: ConnectionStatus.reconnecting),
      );
      expect(_glyphKind(tester), 'ring');
    });
  });

  group('ConnectionPill layout', () {
    testWidgets('pill variant is at least 32 high and fully rounded', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const ConnectionPill(status: ConnectionStatus.connected),
      );
      final size = tester.getSize(find.byType(ConnectionPill));
      expect(size.height, greaterThanOrEqualTo(32));
      final container = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(ConnectionPill),
              matching: find.byType(Container),
            ),
          )
          .firstWhere(
            (c) =>
                c.decoration is BoxDecoration &&
                (c.decoration as BoxDecoration).borderRadius != null,
          );
      final decoration = container.decoration as BoxDecoration;
      expect(
        decoration.borderRadius,
        BorderRadius.circular(CardoRadii.standard.pill),
      );
      expect(decoration.color, CardoColors.light.connected.background);
    });

    testWidgets('compact variant has no pill background', (tester) async {
      await pumpApp(
        tester,
        const ConnectionPill(
          status: ConnectionStatus.connected,
          variant: ConnectionPillVariant.compact,
        ),
      );
      final withRadius = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(ConnectionPill),
              matching: find.byType(Container),
            ),
          )
          .where(
            (c) =>
                c.decoration is BoxDecoration &&
                (c.decoration as BoxDecoration).borderRadius != null,
          );
      expect(withRadius, isEmpty);
    });

    testWidgets('pill text color uses swatch foreground in dark', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const ConnectionPill(status: ConnectionStatus.offline),
        brightness: Brightness.dark,
      );
      final text = tester.widget<Text>(find.text('Офлайн'));
      expect(text.style!.color, CardoColors.dark.offline.foreground);
    });
  });

  group('ConnectionPill static helpers', () {
    testWidgets('swatchFor maps each status', (tester) async {
      const c = CardoColors.light;
      expect(
        ConnectionPill.swatchFor(c, ConnectionStatus.connected),
        c.connected,
      );
      expect(ConnectionPill.swatchFor(c, ConnectionStatus.syncing), c.syncing);
      expect(
        ConnectionPill.swatchFor(c, ConnectionStatus.reconnecting),
        c.reconnecting,
      );
      expect(ConnectionPill.swatchFor(c, ConnectionStatus.offline), c.offline);
    });
  });

  group('ConnectionPill semantics', () {
    testWidgets('is a live region with status label', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        const ConnectionPill(
          status: ConnectionStatus.reconnecting,
          reconnectSeconds: 4,
        ),
      );
      expect(
        tester.getSemantics(find.byType(ConnectionPill)),
        matchesSemantics(
          label: 'Соединение: Переподключение',
          isLiveRegion: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('compact is also a live region', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        const ConnectionPill(
          status: ConnectionStatus.offline,
          variant: ConnectionPillVariant.compact,
        ),
      );
      expect(
        tester.getSemantics(find.byType(ConnectionPill)),
        matchesSemantics(label: 'Соединение: Офлайн', isLiveRegion: true),
      );
      handle.dispose();
    });

    testWidgets('countdown tick changes text but not the announced label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      Future<void> pumpSeconds(int seconds) {
        return pumpApp(
          tester,
          ConnectionPill(
            status: ConnectionStatus.reconnecting,
            reconnectSeconds: seconds,
          ),
        );
      }

      await pumpSeconds(4);
      final before = tester.getSemantics(find.byType(ConnectionPill)).label;
      expect(find.text('Переподключение · 4 с'), findsOneWidget);

      await pumpSeconds(3);
      final after = tester.getSemantics(find.byType(ConnectionPill)).label;
      expect(find.text('Переподключение · 3 с'), findsOneWidget);
      expect(find.text('Переподключение · 4 с'), findsNothing);
      expect(after, before);
      expect(after, 'Соединение: Переподключение');
      expect(after, isNot(contains('3')));
      handle.dispose();
    });
  });
}
