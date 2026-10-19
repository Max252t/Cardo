import 'package:flutter/material.dart';

import 'cardo_colors.dart';
import 'cardo_motion.dart';
import 'cardo_radii.dart';
import 'cardo_shadows.dart';
import 'cardo_sizes.dart';
import 'cardo_spacing.dart';
import 'cardo_typography.dart';

ThemeData buildLightTheme() {
  return _buildTheme(
    colors: CardoColors.light,
    shadows: CardoShadows.light,
    outlinedFill: CardoColors.light.surface,
  );
}

ThemeData buildDarkTheme() {
  return _buildTheme(
    colors: CardoColors.dark,
    shadows: CardoShadows.dark,
    outlinedFill: Colors.transparent,
  );
}

ColorScheme _colorScheme(CardoColors c) {
  return ColorScheme(
    brightness: c.brightness,
    primary: c.emphasis,
    onPrimary: c.onEmphasis,
    primaryContainer: c.column,
    onPrimaryContainer: c.textPrimary,
    secondary: c.accent,
    onSecondary: c.onAccent,
    secondaryContainer: c.selectionFill,
    onSecondaryContainer: c.textPrimary,
    tertiary: c.columnInProgress,
    onTertiary: c.avatarLightText,
    error: c.nackText,
    onError: c.surface,
    errorContainer: c.nackBackground,
    onErrorContainer: c.nackText,
    surface: c.surface,
    onSurface: c.textPrimary,
    onSurfaceVariant: c.textSecondary,
    surfaceDim: c.background,
    surfaceBright: c.card,
    surfaceContainerLowest: c.card,
    surfaceContainerLow: c.card,
    surfaceContainer: c.column,
    surfaceContainerHigh: c.column,
    surfaceContainerHighest: c.column,
    outline: c.lineStrong,
    outlineVariant: c.line,
    shadow: c.avatarDarkText,
    scrim: c.avatarDarkText,
    inverseSurface: c.snackbarBackground,
    onInverseSurface: c.snackbarText,
    inversePrimary: c.accent,
    surfaceTint: Colors.transparent,
  );
}

TextTheme _textTheme(CardoTypography t, CardoColors c) {
  return TextTheme(
    displayLarge: t.display,
    displayMedium: t.display,
    displaySmall: t.titleLarge,
    headlineLarge: t.titleLarge,
    headlineMedium: t.cardTitle,
    headlineSmall: t.title,
    titleLarge: t.title,
    titleMedium: t.body,
    titleSmall: t.bodyDense,
    bodyLarge: t.paragraph,
    bodyMedium: t.body,
    bodySmall: t.caption,
    labelLarge: t.button,
    labelMedium: t.label,
    labelSmall: t.tag,
  ).apply(bodyColor: c.textPrimary, displayColor: c.textPrimary);
}

ThemeData _buildTheme({
  required CardoColors colors,
  required CardoShadows shadows,
  required Color outlinedFill,
}) {
  const typography = CardoTypography.standard;
  const radii = CardoRadii.standard;
  const spacing = CardoSpacing.standard;
  const sizes = CardoSizes.standard;
  const motion = CardoMotion.standard;

  final scheme = _colorScheme(colors);
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radii.button),
  );
  final buttonMinimumSize = Size(sizes.tapTarget, sizes.buttonHeight);
  final buttonPadding = EdgeInsetsDirectional.symmetric(
    horizontal: spacing.buttonPaddingHorizontal,
  );
  final fieldRadius = BorderRadius.circular(radii.field);

  OutlineInputBorder fieldBorder(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: fieldRadius,
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return ThemeData(
    useMaterial3: true,
    brightness: colors.brightness,
    colorScheme: scheme,
    fontFamily: CardoFonts.geist,
    textTheme: _textTheme(typography, colors),
    scaffoldBackgroundColor: colors.background,
    canvasColor: colors.surface,
    dividerColor: colors.line,
    dividerTheme: DividerThemeData(
      color: colors.line,
      thickness: sizes.hairline,
      space: sizes.hairline,
    ),
    iconTheme: IconThemeData(color: colors.textPrimary),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      foregroundColor: colors.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: typography.title.copyWith(color: colors.textPrimary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.emphasis,
        foregroundColor: colors.onEmphasis,
        disabledBackgroundColor: colors.line,
        disabledForegroundColor: colors.textSecondary,
        minimumSize: buttonMinimumSize,
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: typography.button,
        iconSize: sizes.iconButton,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: outlinedFill,
        foregroundColor: colors.textPrimary,
        disabledForegroundColor: colors.textSecondary,
        side: BorderSide(color: colors.lineStrong, width: sizes.hairline),
        minimumSize: buttonMinimumSize,
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: typography.button,
        iconSize: sizes.iconButton,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.textPrimary,
        disabledForegroundColor: colors.textSecondary,
        minimumSize: buttonMinimumSize,
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: spacing.textButtonPaddingHorizontal,
        ),
        shape: buttonShape,
        textStyle: typography.button.copyWith(
          decoration: TextDecoration.underline,
          decorationColor: colors.textPrimary,
        ),
        iconSize: sizes.iconButton,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.field,
      isDense: false,
      contentPadding: EdgeInsetsDirectional.all(spacing.cardPadding),
      hintStyle: typography.body.copyWith(color: colors.textSecondary),
      labelStyle: typography.label.copyWith(color: colors.textSoft),
      floatingLabelStyle: typography.label.copyWith(color: colors.textPrimary),
      helperStyle: typography.caption.copyWith(color: colors.textSecondary),
      errorStyle: typography.caption.copyWith(color: colors.nackText),
      border: fieldBorder(colors.lineStrong, sizes.hairline),
      enabledBorder: fieldBorder(colors.lineStrong, sizes.hairline),
      disabledBorder: fieldBorder(colors.line, sizes.hairline),
      focusedBorder: fieldBorder(colors.emphasis, sizes.emphasisBorder),
      errorBorder: fieldBorder(colors.nackBorder, sizes.hairline),
      focusedErrorBorder: fieldBorder(colors.nackText, sizes.emphasisBorder),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.snackbarBackground,
      contentTextStyle: typography.message.copyWith(color: colors.snackbarText),
      actionTextColor: colors.snackbarActionText,
      actionBackgroundColor: colors.snackbarAction,
      disabledActionTextColor: colors.textSecondary,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radii.snackbar),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surface,
      modalBackgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      showDragHandle: true,
      dragHandleColor: colors.lineStrong,
      dragHandleSize: Size(sizes.sheetHandleWidth, sizes.sheetHandleHeight),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radii.sheet)),
      ),
    ),
    extensions: <ThemeExtension<dynamic>>[
      colors,
      typography,
      radii,
      spacing,
      sizes,
      shadows,
      motion,
    ],
  );
}
