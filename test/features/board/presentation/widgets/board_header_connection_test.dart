import 'package:cardo/core/realtime/connection_status.dart';
import 'package:cardo/features/board/data/fake_board_gateway.dart';
import 'package:cardo/features/board/data/sync_signal.dart';
import 'package:cardo/l10n/app_localizations.dart';
import 'package:cardo/l10n/app_localizations_en.dart';
import 'package:cardo/l10n/app_localizations_ru.dart';
import 'package:cardo/shared/widgets/connection_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/board_fixtures.dart';
import '../../helpers/pump_board.dart';

class Variant {
  const Variant(this.name, this.size, this.locale, this.l10n);

  final String name;
  final Size size;
  final Locale locale;
  final AppLocalizations l10n;
}

final List<Variant> variants = <Variant>[
  Variant('375 ru', compactSize, const Locale('ru'), AppLocalizationsRu()),
  Variant('375 en', compactSize, const Locale('en'), AppLocalizationsEn()),
  Variant('1280 ru', expandedSize, const Locale('ru'), AppLocalizationsRu()),
  Variant('1280 en', expandedSize, const Locale('en'), AppLocalizationsEn()),
];

Finder pillText(String label) => find.descendant(
  of: find.byType(ConnectionPill),
  matching: find.text(label),
);

void main() {
  for (final v in variants) {
    group('header pill at ${v.name}', () {
      testWidgets('shows connected after the handshake', (tester) async {
        final gateway = FakeBoardGateway(confirmDelay: Duration.zero);
        await pumpBoard(
          tester,
          size: v.size,
          locale: v.locale,
          gateway: gateway,
        );
        await tester.pump(const Duration(milliseconds: 50));

        expect(pillText(v.l10n.connectionConnected), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('shows syncing before ready', (tester) async {
        final gateway = ControlledGateway();
        await pumpBoard(
          tester,
          size: v.size,
          locale: v.locale,
          gateway: gateway,
        );

        gateway.emit(const ConnectionSignal(ConnectionStatus.syncing));
        await tester.pump();

        expect(pillText(v.l10n.connectionSyncing), findsOneWidget);
        gateway.emit(const ReadySignal());
        await tester.pump();
        expect(pillText(v.l10n.connectionConnected), findsOneWidget);
      });

      testWidgets('shows offline', (tester) async {
        final gateway = ControlledGateway();
        await pumpBoard(
          tester,
          size: v.size,
          locale: v.locale,
          gateway: gateway,
        );

        gateway.emit(const ConnectionSignal(ConnectionStatus.offline));
        await tester.pump();

        expect(pillText(v.l10n.connectionOffline), findsOneWidget);
      });

      testWidgets('shows reconnecting with the seconds from the engine', (
        tester,
      ) async {
        final gateway = ControlledGateway();
        await pumpBoard(
          tester,
          size: v.size,
          locale: v.locale,
          gateway: gateway,
        );

        for (final seconds in <int>[3, 2, 1]) {
          gateway.emit(
            ConnectionSignal(
              ConnectionStatus.reconnecting,
              reconnectSeconds: seconds,
            ),
          );
          await tester.pump();
          expect(
            pillText(v.l10n.connectionReconnectingIn(seconds)),
            findsOneWidget,
          );
        }
        expect(pillText(v.l10n.connectionReconnectingIn(3)), findsNothing);
      });

      testWidgets('the countdown ticks down by itself on a real reconnect', (
        tester,
      ) async {
        final gateway = FakeBoardGateway(confirmDelay: Duration.zero);
        await pumpBoard(
          tester,
          size: v.size,
          locale: v.locale,
          gateway: gateway,
        );
        await tester.pump(const Duration(milliseconds: 50));
        gateway.server.failNextConnections(3);
        gateway.server.dropConnections();
        await tester.pump(const Duration(milliseconds: 3600));

        expect(pillText(v.l10n.connectionReconnectingIn(4)), findsOneWidget);
        await tester.pump(const Duration(seconds: 1));
        expect(pillText(v.l10n.connectionReconnectingIn(3)), findsOneWidget);
        await tester.pump(const Duration(seconds: 1));
        expect(pillText(v.l10n.connectionReconnectingIn(2)), findsOneWidget);
        await tester.pump(const Duration(seconds: 1));
        expect(pillText(v.l10n.connectionReconnectingIn(1)), findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
        expect(pillText(v.l10n.connectionConnected), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('text scale 2 does not overflow in any state', (
        tester,
      ) async {
        final gateway = ControlledGateway();
        await pumpBoard(
          tester,
          size: v.size,
          locale: v.locale,
          gateway: gateway,
          textScale: 2,
        );

        for (final signal in <ConnectionSignal>[
          const ConnectionSignal(ConnectionStatus.syncing),
          const ConnectionSignal(
            ConnectionStatus.reconnecting,
            reconnectSeconds: 30,
          ),
          const ConnectionSignal(ConnectionStatus.reconnecting),
          const ConnectionSignal(ConnectionStatus.offline),
        ]) {
          gateway.emit(signal);
          await tester.pump();
          expect(tester.takeException(), isNull, reason: signal.toString());
        }
        gateway.emit(const ReadySignal());
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    });
  }
}
