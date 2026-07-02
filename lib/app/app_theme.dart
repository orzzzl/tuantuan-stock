import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tuantuan_stock/app/cute_palette.dart';

ThemeData buildAppTheme() {
  final colorScheme = _buildColorScheme();
  final textTheme = _buildTextTheme(colorScheme);
  const cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(20)),
    side: BorderSide(color: CuteColors.borderWarm, width: 2),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: CuteColors.matcha,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: CuteColors.matcha,
        fontWeight: FontWeight.w900,
      ),
    ),
    cardTheme: const CardThemeData(
      color: CuteColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: cardShape,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: CuteColors.card,
      selectedColor: CuteColors.peachDeep,
      disabledColor: CuteColors.peachSurface,
      secondarySelectedColor: CuteColors.peachDeep,
      labelStyle: textTheme.labelLarge?.copyWith(color: CuteColors.peachText),
      secondaryLabelStyle: textTheme.labelLarge?.copyWith(
        color: CuteColors.card,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      side: const BorderSide(color: CuteColors.peachBorder, width: 2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(13)),
      ),
      showCheckmark: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: CuteColors.peachInput,
      border: _inputBorder(CuteColors.peachInputBorder),
      enabledBorder: _inputBorder(CuteColors.peachInputBorder),
      focusedBorder: _inputBorder(CuteColors.peachDeep),
      errorBorder: _inputBorder(CuteColors.down),
      focusedErrorBorder: _inputBorder(CuteColors.down),
      hintStyle: textTheme.bodyMedium?.copyWith(color: CuteColors.textDisabled),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: CuteColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(26)),
        side: BorderSide(color: CuteColors.borderWarm, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CuteColors.matchaEnd,
        foregroundColor: CuteColors.card,
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: CuteColors.peachText,
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
        side: const BorderSide(color: CuteColors.peachBorder, width: 2),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      ),
    ),
  );
}

ColorScheme _buildColorScheme() {
  return const ColorScheme(
    brightness: Brightness.light,
    primary: CuteColors.matcha,
    onPrimary: CuteColors.card,
    primaryContainer: CuteColors.upBackground,
    onPrimaryContainer: CuteColors.matcha,
    primaryFixed: CuteColors.upBackground,
    primaryFixedDim: CuteColors.matchaSoft,
    onPrimaryFixed: CuteColors.matcha,
    onPrimaryFixedVariant: CuteColors.up,
    secondary: CuteColors.peachDeep,
    onSecondary: CuteColors.card,
    secondaryContainer: CuteColors.peachSurface,
    onSecondaryContainer: CuteColors.peachText,
    secondaryFixed: CuteColors.peachSurface,
    secondaryFixedDim: CuteColors.peach,
    onSecondaryFixed: CuteColors.text,
    onSecondaryFixedVariant: CuteColors.peachText,
    tertiary: CuteColors.waterLine,
    onTertiary: CuteColors.text,
    tertiaryContainer: CuteColors.water,
    onTertiaryContainer: CuteColors.text,
    tertiaryFixed: CuteColors.water,
    tertiaryFixedDim: CuteColors.waterRipple,
    onTertiaryFixed: CuteColors.text,
    onTertiaryFixedVariant: CuteColors.waterLabel,
    error: CuteColors.down,
    onError: CuteColors.card,
    errorContainer: CuteColors.downBackground,
    onErrorContainer: CuteColors.down,
    surface: CuteColors.surface,
    onSurface: CuteColors.text,
    surfaceDim: CuteColors.cream,
    surfaceBright: CuteColors.card,
    surfaceContainerLowest: CuteColors.card,
    surfaceContainerLow: CuteColors.surface,
    surfaceContainer: CuteColors.peachSurface,
    surfaceContainerHigh: CuteColors.shadowWarm,
    surfaceContainerHighest: CuteColors.borderWarm,
    onSurfaceVariant: CuteColors.textMuted,
    outline: CuteColors.borderWarm,
    outlineVariant: CuteColors.borderSoft,
    shadow: CuteColors.shadowWarm,
    scrim: CuteColors.textDark,
    inverseSurface: CuteColors.text,
    onInverseSurface: CuteColors.surface,
    inversePrimary: CuteColors.matchaLight,
    surfaceTint: Colors.transparent,
  );
}

TextTheme _buildTextTheme(ColorScheme colorScheme) {
  final baseTheme = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
  ).textTheme;
  final fallbackFamily = GoogleFonts.zcoolKuaiLe().fontFamily;

  TextStyle? cute(TextStyle? style, FontWeight weight) {
    final baseStyle = style?.copyWith(
      color: CuteColors.text,
      fontFeatures: const [FontFeature.tabularFigures()],
      letterSpacing: 0,
    );

    return GoogleFonts.baloo2(
      textStyle: baseStyle,
      fontWeight: weight,
    ).copyWith(fontFamilyFallback: [?fallbackFamily]);
  }

  return baseTheme.copyWith(
    displayLarge: cute(baseTheme.displayLarge, FontWeight.w900),
    displayMedium: cute(baseTheme.displayMedium, FontWeight.w900),
    displaySmall: cute(baseTheme.displaySmall, FontWeight.w900),
    headlineLarge: cute(baseTheme.headlineLarge, FontWeight.w900),
    headlineMedium: cute(baseTheme.headlineMedium, FontWeight.w800),
    headlineSmall: cute(baseTheme.headlineSmall, FontWeight.w800),
    titleLarge: cute(baseTheme.titleLarge, FontWeight.w900),
    titleMedium: cute(baseTheme.titleMedium, FontWeight.w800),
    titleSmall: cute(baseTheme.titleSmall, FontWeight.w800),
    bodyLarge: cute(baseTheme.bodyLarge, FontWeight.w700),
    bodyMedium: cute(baseTheme.bodyMedium, FontWeight.w700),
    bodySmall: cute(baseTheme.bodySmall, FontWeight.w600),
    labelLarge: cute(baseTheme.labelLarge, FontWeight.w800),
    labelMedium: cute(baseTheme.labelMedium, FontWeight.w800),
    labelSmall: cute(baseTheme.labelSmall, FontWeight.w800),
  );
}

OutlineInputBorder _inputBorder(Color color) {
  return OutlineInputBorder(
    borderRadius: const BorderRadius.all(Radius.circular(18)),
    borderSide: BorderSide(color: color, width: 2),
  );
}
