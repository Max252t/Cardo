import 'package:flutter/material.dart';

import 'cardo_avatar_palette.dart';
import 'cardo_primitives.dart';
import 'cardo_swatches.dart';

@immutable
class CardoColors extends ThemeExtension<CardoColors> {
  const CardoColors({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.card,
    required this.cardBorder,
    required this.column,
    required this.columnBorder,
    required this.line,
    required this.lineStrong,
    required this.field,
    required this.textPrimary,
    required this.textSecondary,
    required this.textSoft,
    required this.emphasis,
    required this.onEmphasis,
    required this.accent,
    required this.onAccent,
    required this.dragBorder,
    required this.dropPlaceholderFill,
    required this.dropPlaceholderBorder,
    required this.selectionFill,
    required this.pendingBorder,
    required this.columnBacklog,
    required this.columnInProgress,
    required this.columnReview,
    required this.columnDone,
    required this.connected,
    required this.syncing,
    required this.reconnecting,
    required this.offline,
    required this.conflictBackground,
    required this.conflictTitle,
    required this.conflictText,
    required this.conflictBorder,
    required this.nackBackground,
    required this.nackBorder,
    required this.nackText,
    required this.snackbarBackground,
    required this.snackbarText,
    required this.snackbarIcon,
    required this.snackbarAction,
    required this.snackbarActionText,
    required this.roleViewerBackground,
    required this.roleViewerText,
    required this.avatarLightText,
    required this.avatarDarkText,
    required this.avatarFallback,
    required this.avatarFallbackAccent,
    required this.avatarOverflowBackground,
    required this.avatarOverflowText,
  });

  static const CardoColors light = CardoColors(
    brightness: Brightness.light,
    background: CardoPrimitives.neutralEEF0F3,
    surface: CardoPrimitives.neutralFFFFFF,
    card: CardoPrimitives.neutralFFFFFF,
    cardBorder: CardoPrimitives.neutralDDE1E7,
    column: CardoPrimitives.neutralE4E7EC,
    columnBorder: CardoPrimitives.neutralE4E7EC,
    line: CardoPrimitives.neutralDDE1E7,
    lineStrong: CardoPrimitives.neutralC9CED6,
    field: CardoPrimitives.neutralFFFFFF,
    textPrimary: CardoPrimitives.neutral111318,
    textSecondary: CardoPrimitives.neutral5B616E,
    textSoft: CardoPrimitives.neutral3B414D,
    emphasis: CardoPrimitives.neutral111318,
    onEmphasis: CardoPrimitives.neutralFFFFFF,
    accent: CardoPrimitives.orangeFF5B2E,
    onAccent: CardoPrimitives.neutral111318,
    dragBorder: CardoPrimitives.orangeFF5B2E,
    dropPlaceholderFill: Color.fromRGBO(255, 91, 46, 0.07),
    dropPlaceholderBorder: CardoPrimitives.orangeFF5B2E,
    selectionFill: CardoPrimitives.neutralE4E7EC,
    pendingBorder: CardoPrimitives.neutral8A93A3,
    columnBacklog: CardoPrimitives.neutral8A93A3,
    columnInProgress: CardoPrimitives.blue2D68F5,
    columnReview: CardoPrimitives.amberF2A516,
    columnDone: CardoPrimitives.green13804F,
    connected: ConnectionSwatch(
      background: CardoPrimitives.greenE3F3EA,
      foreground: CardoPrimitives.green0E5E3A,
      glyph: CardoPrimitives.green13804F,
      compactForeground: CardoPrimitives.green0E5E3A,
      compactGlyph: CardoPrimitives.green13804F,
    ),
    syncing: ConnectionSwatch(
      background: CardoPrimitives.blueE4ECFF,
      foreground: CardoPrimitives.blue1D47B8,
      glyph: CardoPrimitives.blue1D47B8,
      compactForeground: CardoPrimitives.blue1D47B8,
      compactGlyph: CardoPrimitives.blue1D47B8,
    ),
    reconnecting: ConnectionSwatch(
      background: CardoPrimitives.amberFDF0D2,
      foreground: CardoPrimitives.amber7A4C00,
      glyph: CardoPrimitives.amberB87800,
      compactForeground: CardoPrimitives.amber7A4C00,
      compactGlyph: CardoPrimitives.amberB87800,
    ),
    offline: ConnectionSwatch(
      background: CardoPrimitives.neutral111318,
      foreground: CardoPrimitives.neutralFFFFFF,
      glyph: CardoPrimitives.neutralFFFFFF,
      compactForeground: CardoPrimitives.neutral111318,
      compactGlyph: CardoPrimitives.neutral111318,
    ),
    conflictBackground: CardoPrimitives.amberFDF0D2,
    conflictTitle: CardoPrimitives.amber4D3000,
    conflictText: CardoPrimitives.amber5E3D00,
    conflictBorder: CardoPrimitives.amberC9A65C,
    nackBackground: CardoPrimitives.orangeFFF4EF,
    nackBorder: CardoPrimitives.orangeF3B9A4,
    nackText: CardoPrimitives.orangeA3300B,
    snackbarBackground: CardoPrimitives.neutral111318,
    snackbarText: CardoPrimitives.neutralFFFFFF,
    snackbarIcon: CardoPrimitives.orangeFF8A66,
    snackbarAction: CardoPrimitives.neutral2A2D36,
    snackbarActionText: CardoPrimitives.neutralFFFFFF,
    roleViewerBackground: CardoPrimitives.neutralE4E7EC,
    roleViewerText: CardoPrimitives.neutral3B414D,
    avatarLightText: CardoPrimitives.neutralFFFFFF,
    avatarDarkText: CardoPrimitives.neutral111318,
    avatarFallback: CardoPrimitives.neutral5B616E,
    avatarFallbackAccent: CardoPrimitives.neutral5B616E,
    avatarOverflowBackground: CardoPrimitives.neutralE4E7EC,
    avatarOverflowText: CardoPrimitives.neutral3B414D,
  );

  static const CardoColors dark = CardoColors(
    brightness: Brightness.dark,
    background: CardoPrimitives.neutral0E0F13,
    surface: CardoPrimitives.neutral121318,
    card: CardoPrimitives.neutral1E2028,
    cardBorder: CardoPrimitives.neutral2A2D36,
    column: CardoPrimitives.neutral15171C,
    columnBorder: CardoPrimitives.neutral22242B,
    line: CardoPrimitives.neutral23252D,
    lineStrong: CardoPrimitives.neutral2E313B,
    field: CardoPrimitives.neutral17191F,
    textPrimary: CardoPrimitives.neutralECEDF0,
    textSecondary: CardoPrimitives.neutral9097A3,
    textSoft: CardoPrimitives.neutralC3C7CF,
    emphasis: CardoPrimitives.neutralECEDF0,
    onEmphasis: CardoPrimitives.neutral111318,
    accent: CardoPrimitives.orangeFF5B2E,
    onAccent: CardoPrimitives.neutral111318,
    dragBorder: CardoPrimitives.orangeFF5B2E,
    dropPlaceholderFill: Color.fromRGBO(255, 91, 46, 0.08),
    dropPlaceholderBorder: CardoPrimitives.orangeFF5B2E,
    selectionFill: CardoPrimitives.neutral23252D,
    pendingBorder: CardoPrimitives.neutral5B616E,
    columnBacklog: CardoPrimitives.neutral8A93A3,
    columnInProgress: CardoPrimitives.blue6E97FF,
    columnReview: CardoPrimitives.amberF2A516,
    columnDone: CardoPrimitives.green2FBF7F,
    connected: ConnectionSwatch(
      background: CardoPrimitives.green132A20,
      foreground: CardoPrimitives.green5FD49D,
      glyph: CardoPrimitives.green2FBF7F,
      compactForeground: CardoPrimitives.green5FD49D,
      compactGlyph: CardoPrimitives.green2FBF7F,
    ),
    syncing: ConnectionSwatch(
      background: CardoPrimitives.blue18223F,
      foreground: CardoPrimitives.blue9DB8FF,
      glyph: CardoPrimitives.blue9DB8FF,
      compactForeground: CardoPrimitives.blue9DB8FF,
      compactGlyph: CardoPrimitives.blue9DB8FF,
    ),
    reconnecting: ConnectionSwatch(
      background: CardoPrimitives.amber2E2410,
      foreground: CardoPrimitives.amberF2C25E,
      glyph: CardoPrimitives.amberE0A526,
      compactForeground: CardoPrimitives.amberF2C25E,
      compactGlyph: CardoPrimitives.amberE0A526,
    ),
    offline: ConnectionSwatch(
      background: CardoPrimitives.neutralECEDF0,
      foreground: CardoPrimitives.neutral111318,
      glyph: CardoPrimitives.neutral111318,
      compactForeground: CardoPrimitives.neutralECEDF0,
      compactGlyph: CardoPrimitives.neutralECEDF0,
    ),
    conflictBackground: CardoPrimitives.amber2E2410,
    conflictTitle: CardoPrimitives.amberF7D58A,
    conflictText: CardoPrimitives.amberE8C97E,
    conflictBorder: CardoPrimitives.amber7A6230,
    nackBackground: CardoPrimitives.orange2A1812,
    nackBorder: CardoPrimitives.orange6B2F1C,
    nackText: CardoPrimitives.orangeFF9A7A,
    snackbarBackground: CardoPrimitives.neutral2A2D36,
    snackbarText: CardoPrimitives.neutralECEDF0,
    snackbarIcon: CardoPrimitives.orangeFF8A66,
    snackbarAction: CardoPrimitives.neutral3A3E4A,
    snackbarActionText: CardoPrimitives.neutralECEDF0,
    roleViewerBackground: CardoPrimitives.neutral2A2D36,
    roleViewerText: CardoPrimitives.neutralC3C7CF,
    avatarLightText: CardoPrimitives.neutralFFFFFF,
    avatarDarkText: CardoPrimitives.neutral111318,
    avatarFallback: CardoPrimitives.neutral5B616E,
    avatarFallbackAccent: CardoPrimitives.neutral8A93A3,
    avatarOverflowBackground: CardoPrimitives.neutral2A2D36,
    avatarOverflowText: CardoPrimitives.neutralC3C7CF,
  );

  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color card;
  final Color cardBorder;
  final Color column;
  final Color columnBorder;
  final Color line;
  final Color lineStrong;
  final Color field;
  final Color textPrimary;
  final Color textSecondary;
  final Color textSoft;
  final Color emphasis;
  final Color onEmphasis;
  final Color accent;
  final Color onAccent;
  final Color dragBorder;
  final Color dropPlaceholderFill;
  final Color dropPlaceholderBorder;
  final Color selectionFill;
  final Color pendingBorder;
  final Color columnBacklog;
  final Color columnInProgress;
  final Color columnReview;
  final Color columnDone;
  final ConnectionSwatch connected;
  final ConnectionSwatch syncing;
  final ConnectionSwatch reconnecting;
  final ConnectionSwatch offline;
  final Color conflictBackground;
  final Color conflictTitle;
  final Color conflictText;
  final Color conflictBorder;
  final Color nackBackground;
  final Color nackBorder;
  final Color nackText;
  final Color snackbarBackground;
  final Color snackbarText;
  final Color snackbarIcon;
  final Color snackbarAction;
  final Color snackbarActionText;
  final Color roleViewerBackground;
  final Color roleViewerText;
  final Color avatarLightText;
  final Color avatarDarkText;
  final Color avatarFallback;
  final Color avatarFallbackAccent;
  final Color avatarOverflowBackground;
  final Color avatarOverflowText;

  static CardoColors of(BuildContext context) {
    final extension = Theme.of(context).extension<CardoColors>();
    assert(
      extension != null,
      'CardoColors missing: build ThemeData via buildLightTheme/buildDarkTheme',
    );
    return extension!;
  }

  AvatarSwatch avatarSwatch(String? hex) {
    return CardoAvatarPalette.resolve(
      hex: hex,
      brightness: brightness,
      fallback: avatarFallback,
      fallbackAccent: avatarFallbackAccent,
      lightText: avatarLightText,
      darkText: avatarDarkText,
    );
  }

  @override
  CardoColors copyWith({
    Brightness? brightness,
    Color? background,
    Color? surface,
    Color? card,
    Color? cardBorder,
    Color? column,
    Color? columnBorder,
    Color? line,
    Color? lineStrong,
    Color? field,
    Color? textPrimary,
    Color? textSecondary,
    Color? textSoft,
    Color? emphasis,
    Color? onEmphasis,
    Color? accent,
    Color? onAccent,
    Color? dragBorder,
    Color? dropPlaceholderFill,
    Color? dropPlaceholderBorder,
    Color? selectionFill,
    Color? pendingBorder,
    Color? columnBacklog,
    Color? columnInProgress,
    Color? columnReview,
    Color? columnDone,
    ConnectionSwatch? connected,
    ConnectionSwatch? syncing,
    ConnectionSwatch? reconnecting,
    ConnectionSwatch? offline,
    Color? conflictBackground,
    Color? conflictTitle,
    Color? conflictText,
    Color? conflictBorder,
    Color? nackBackground,
    Color? nackBorder,
    Color? nackText,
    Color? snackbarBackground,
    Color? snackbarText,
    Color? snackbarIcon,
    Color? snackbarAction,
    Color? snackbarActionText,
    Color? roleViewerBackground,
    Color? roleViewerText,
    Color? avatarLightText,
    Color? avatarDarkText,
    Color? avatarFallback,
    Color? avatarFallbackAccent,
    Color? avatarOverflowBackground,
    Color? avatarOverflowText,
  }) {
    return CardoColors(
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      cardBorder: cardBorder ?? this.cardBorder,
      column: column ?? this.column,
      columnBorder: columnBorder ?? this.columnBorder,
      line: line ?? this.line,
      lineStrong: lineStrong ?? this.lineStrong,
      field: field ?? this.field,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textSoft: textSoft ?? this.textSoft,
      emphasis: emphasis ?? this.emphasis,
      onEmphasis: onEmphasis ?? this.onEmphasis,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      dragBorder: dragBorder ?? this.dragBorder,
      dropPlaceholderFill: dropPlaceholderFill ?? this.dropPlaceholderFill,
      dropPlaceholderBorder:
          dropPlaceholderBorder ?? this.dropPlaceholderBorder,
      selectionFill: selectionFill ?? this.selectionFill,
      pendingBorder: pendingBorder ?? this.pendingBorder,
      columnBacklog: columnBacklog ?? this.columnBacklog,
      columnInProgress: columnInProgress ?? this.columnInProgress,
      columnReview: columnReview ?? this.columnReview,
      columnDone: columnDone ?? this.columnDone,
      connected: connected ?? this.connected,
      syncing: syncing ?? this.syncing,
      reconnecting: reconnecting ?? this.reconnecting,
      offline: offline ?? this.offline,
      conflictBackground: conflictBackground ?? this.conflictBackground,
      conflictTitle: conflictTitle ?? this.conflictTitle,
      conflictText: conflictText ?? this.conflictText,
      conflictBorder: conflictBorder ?? this.conflictBorder,
      nackBackground: nackBackground ?? this.nackBackground,
      nackBorder: nackBorder ?? this.nackBorder,
      nackText: nackText ?? this.nackText,
      snackbarBackground: snackbarBackground ?? this.snackbarBackground,
      snackbarText: snackbarText ?? this.snackbarText,
      snackbarIcon: snackbarIcon ?? this.snackbarIcon,
      snackbarAction: snackbarAction ?? this.snackbarAction,
      snackbarActionText: snackbarActionText ?? this.snackbarActionText,
      roleViewerBackground: roleViewerBackground ?? this.roleViewerBackground,
      roleViewerText: roleViewerText ?? this.roleViewerText,
      avatarLightText: avatarLightText ?? this.avatarLightText,
      avatarDarkText: avatarDarkText ?? this.avatarDarkText,
      avatarFallback: avatarFallback ?? this.avatarFallback,
      avatarFallbackAccent: avatarFallbackAccent ?? this.avatarFallbackAccent,
      avatarOverflowBackground:
          avatarOverflowBackground ?? this.avatarOverflowBackground,
      avatarOverflowText: avatarOverflowText ?? this.avatarOverflowText,
    );
  }

  @override
  CardoColors lerp(covariant ThemeExtension<CardoColors>? other, double t) {
    if (other is! CardoColors) {
      return this;
    }
    Color c(Color a, Color b) => lerpColor(a, b, t);
    return CardoColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: c(background, other.background),
      surface: c(surface, other.surface),
      card: c(card, other.card),
      cardBorder: c(cardBorder, other.cardBorder),
      column: c(column, other.column),
      columnBorder: c(columnBorder, other.columnBorder),
      line: c(line, other.line),
      lineStrong: c(lineStrong, other.lineStrong),
      field: c(field, other.field),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textSoft: c(textSoft, other.textSoft),
      emphasis: c(emphasis, other.emphasis),
      onEmphasis: c(onEmphasis, other.onEmphasis),
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      dragBorder: c(dragBorder, other.dragBorder),
      dropPlaceholderFill: c(dropPlaceholderFill, other.dropPlaceholderFill),
      dropPlaceholderBorder: c(
        dropPlaceholderBorder,
        other.dropPlaceholderBorder,
      ),
      selectionFill: c(selectionFill, other.selectionFill),
      pendingBorder: c(pendingBorder, other.pendingBorder),
      columnBacklog: c(columnBacklog, other.columnBacklog),
      columnInProgress: c(columnInProgress, other.columnInProgress),
      columnReview: c(columnReview, other.columnReview),
      columnDone: c(columnDone, other.columnDone),
      connected: ConnectionSwatch.lerp(connected, other.connected, t),
      syncing: ConnectionSwatch.lerp(syncing, other.syncing, t),
      reconnecting: ConnectionSwatch.lerp(reconnecting, other.reconnecting, t),
      offline: ConnectionSwatch.lerp(offline, other.offline, t),
      conflictBackground: c(conflictBackground, other.conflictBackground),
      conflictTitle: c(conflictTitle, other.conflictTitle),
      conflictText: c(conflictText, other.conflictText),
      conflictBorder: c(conflictBorder, other.conflictBorder),
      nackBackground: c(nackBackground, other.nackBackground),
      nackBorder: c(nackBorder, other.nackBorder),
      nackText: c(nackText, other.nackText),
      snackbarBackground: c(snackbarBackground, other.snackbarBackground),
      snackbarText: c(snackbarText, other.snackbarText),
      snackbarIcon: c(snackbarIcon, other.snackbarIcon),
      snackbarAction: c(snackbarAction, other.snackbarAction),
      snackbarActionText: c(snackbarActionText, other.snackbarActionText),
      roleViewerBackground: c(roleViewerBackground, other.roleViewerBackground),
      roleViewerText: c(roleViewerText, other.roleViewerText),
      avatarLightText: c(avatarLightText, other.avatarLightText),
      avatarDarkText: c(avatarDarkText, other.avatarDarkText),
      avatarFallback: c(avatarFallback, other.avatarFallback),
      avatarFallbackAccent: c(avatarFallbackAccent, other.avatarFallbackAccent),
      avatarOverflowBackground: c(
        avatarOverflowBackground,
        other.avatarOverflowBackground,
      ),
      avatarOverflowText: c(avatarOverflowText, other.avatarOverflowText),
    );
  }
}
