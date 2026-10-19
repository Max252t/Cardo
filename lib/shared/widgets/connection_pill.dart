import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/realtime/connection_status.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/cardo_theme.dart';

enum ConnectionPillVariant { pill, compact }

class ConnectionPill extends StatelessWidget {
  const ConnectionPill({
    super.key,
    required this.status,
    this.reconnectSeconds,
    this.variant = ConnectionPillVariant.pill,
  });

  final ConnectionStatus status;
  final int? reconnectSeconds;
  final ConnectionPillVariant variant;

  static String labelFor(
    AppLocalizations l10n,
    ConnectionStatus status,
    int? reconnectSeconds,
  ) {
    return switch (status) {
      ConnectionStatus.connected => l10n.connectionConnected,
      ConnectionStatus.syncing => l10n.connectionSyncing,
      ConnectionStatus.reconnecting when reconnectSeconds != null =>
        l10n.connectionReconnectingIn(reconnectSeconds),
      ConnectionStatus.reconnecting => l10n.connectionReconnecting,
      ConnectionStatus.offline => l10n.connectionOffline,
    };
  }

  static ConnectionSwatch swatchFor(
    CardoColors colors,
    ConnectionStatus status,
  ) {
    return switch (status) {
      ConnectionStatus.connected => colors.connected,
      ConnectionStatus.syncing => colors.syncing,
      ConnectionStatus.reconnecting => colors.reconnecting,
      ConnectionStatus.offline => colors.offline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = CardoColors.of(context);
    final typography = CardoTypography.of(context);
    final sizes = CardoSizes.of(context);
    final spacing = CardoSpacing.of(context);
    final label = labelFor(l10n, status, reconnectSeconds);
    final swatch = swatchFor(colors, status);
    final compact = variant == ConnectionPillVariant.compact;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ConnectionGlyph(
          status: status,
          color: compact ? swatch.compactGlyph : swatch.glyph,
          compact: compact,
        ),
        SizedBox(width: compact ? spacing.iconGap : spacing.pillGap),
        Flexible(
          child: Text(
            label,
            style: (compact ? typography.caption : typography.pill).copyWith(
              color: compact ? swatch.compactForeground : swatch.foreground,
            ),
          ),
        ),
      ],
    );
    return Semantics(
      liveRegion: true,
      label: l10n.connectionSemanticLabel(labelFor(l10n, status, null)),
      child: ExcludeSemantics(
        child: compact
            ? content
            : Container(
                constraints: BoxConstraints(minHeight: sizes.pillHeight),
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: spacing.pillPaddingHorizontal,
                ),
                decoration: BoxDecoration(
                  color: swatch.background,
                  borderRadius: BorderRadius.circular(
                    CardoRadii.of(context).pill,
                  ),
                ),
                child: content,
              ),
      ),
    );
  }
}

class ConnectionGlyph extends StatelessWidget {
  const ConnectionGlyph({
    super.key,
    required this.status,
    required this.color,
    required this.compact,
  });

  final ConnectionStatus status;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final sizes = CardoSizes.of(context);
    final dot = compact ? sizes.statusDotCompact : sizes.statusDot;
    final icon = compact ? sizes.iconCompact : sizes.iconPill;
    return switch (status) {
      ConnectionStatus.connected => Container(
        width: dot,
        height: dot,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
      ConnectionStatus.syncing => Icon(
        LucideIcons.refreshCw,
        size: icon,
        color: color,
      ),
      ConnectionStatus.reconnecting => Container(
        width: dot,
        height: dot,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: sizes.ringStroke),
        ),
      ),
      ConnectionStatus.offline => Icon(
        LucideIcons.wifiOff,
        size: icon,
        color: color,
      ),
    };
  }
}
