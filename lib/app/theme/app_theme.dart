import 'package:flutter/material.dart';

import '../../domain/theme_choice.dart';
import 'tavli_colors.dart';
import 'tavli_palette.dart';
import 'tavli_status_colors.dart';

/// Ugrađen font (assets/fonts).
const tavliFontFamily = 'PlusJakartaSans';

/// [ThemeData] za temu i osvetljenost: [ColorScheme] je sastavljen ručno od
/// odobrenih tokena (ne `fromSeed`), ostali tokeni su u [TavliColors].
ThemeData buildTavliTheme(TavliTheme theme, Brightness brightness) {
  final p = TavliPalette.of(theme, brightness);
  final dark = brightness == Brightness.dark;
  final other = TavliPalette.of(
    theme,
    dark ? Brightness.light : Brightness.dark,
  );
  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.primary,
    onPrimary: p.onPrimary,
    primaryContainer: p.container,
    onPrimaryContainer: p.onContainer,
    secondary: p.primary,
    onSecondary: p.onPrimary,
    secondaryContainer: p.container,
    onSecondaryContainer: p.onContainer,
    tertiary: p.onContainer,
    onTertiary: p.container,
    tertiaryContainer: p.tints.first,
    onTertiaryContainer: p.text,
    // Material 3 osnovne boje greške.
    error: dark ? const Color(0xFFF2B8B5) : const Color(0xFFB3261E),
    onError: dark ? const Color(0xFF601410) : const Color(0xFFFFFFFF),
    errorContainer: dark ? const Color(0xFF8C1D18) : const Color(0xFFF9DEDC),
    onErrorContainer: dark ? const Color(0xFFF9DEDC) : const Color(0xFF410E0B),
    surface: p.surface,
    onSurface: p.text,
    onSurfaceVariant: p.muted,
    surfaceDim: p.bg,
    surfaceBright: dark ? p.line : p.surface,
    surfaceContainerLowest: dark ? p.bg : p.surface,
    surfaceContainerLow: Color.lerp(p.surface, p.bg, 0.5),
    surfaceContainer: dark ? p.surface : p.bg,
    surfaceContainerHigh: dark
        ? Color.lerp(p.surface, p.line, 0.35)
        : Color.lerp(p.bg, p.line, 0.5),
    surfaceContainerHighest: p.line,
    outline: p.boxLine,
    outlineVariant: p.line,
    shadow: const Color(0xFF000000),
    scrim: const Color(0xFF000000),
    inverseSurface: p.text,
    onInverseSurface: p.bg,
    inversePrimary: other.primary,
    surfaceTint: const Color(0x00000000),
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: tavliFontFamily,
  );
  final text = base.textTheme;
  TextStyle? heading(TextStyle? s, {FontWeight weight = FontWeight.w700}) => s
      ?.copyWith(fontWeight: weight, letterSpacing: -0.02 * (s.fontSize ?? 16));
  final textTheme = text.copyWith(
    displayLarge: heading(text.displayLarge, weight: FontWeight.w800),
    displayMedium: heading(text.displayMedium, weight: FontWeight.w800),
    displaySmall: heading(text.displaySmall, weight: FontWeight.w800),
    headlineLarge: heading(text.headlineLarge, weight: FontWeight.w800),
    headlineMedium: heading(text.headlineMedium),
    headlineSmall: heading(text.headlineSmall),
    titleLarge: heading(text.titleLarge),
    titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    bodyLarge: text.bodyLarge?.copyWith(fontSize: 16, height: 1.55),
    bodyMedium: text.bodyMedium?.copyWith(fontSize: 16, height: 1.5),
    labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
  );

  final lineSide = BorderSide(color: p.line);
  WidgetStateProperty<T> selected<T>(T on, T off) =>
      WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? on : off,
      );

  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    textTheme: textTheme,
    extensions: [
      dark ? TavliStatusColors.dark : TavliStatusColors.light,
      TavliColors(
        motif: theme,
        bg: p.bg,
        line: p.line,
        boxLine: p.boxLine,
        tints: p.tints,
      ),
    ],
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: p.text),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: lineSide,
      ),
    ),
    chipTheme: ChipThemeData(
      color: selected(p.primary, p.surface),
      side: WidgetStateBorderSide.resolveWith(
        (s) => s.contains(WidgetState.selected) ? BorderSide.none : lineSide,
      ),
      shape: const StadiumBorder(),
      labelStyle: textTheme.labelLarge?.copyWith(
        color: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.onPrimary : p.text,
        ),
      ),
      checkmarkColor: p.onPrimary,
      iconTheme: IconThemeData(color: p.muted, size: 18),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: textTheme.labelLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        foregroundColor: p.text,
        side: BorderSide(color: p.boxLine),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(p.surface),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      side: WidgetStatePropertyAll(lineSide),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      constraints: const BoxConstraints(minHeight: 50),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16),
      ),
      hintStyle: WidgetStatePropertyAll(
        textTheme.bodyLarge?.copyWith(color: p.muted, fontSize: 16),
      ),
      textStyle: WidgetStatePropertyAll(
        textTheme.bodyLarge?.copyWith(color: p.text, fontSize: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: lineSide,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: lineSide,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: p.primary, width: 2),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: p.container,
      indicatorShape: const StadiumBorder(),
      iconTheme: selected(
        IconThemeData(color: p.onContainer),
        IconThemeData(color: p.muted),
      ),
      labelTextStyle: selected(
        textTheme.labelMedium?.copyWith(
          color: p.onContainer,
          fontWeight: FontWeight.w700,
        ),
        textTheme.labelMedium?.copyWith(
          color: p.muted,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: p.surface,
      indicatorColor: p.container,
      indicatorShape: const StadiumBorder(),
      selectedIconTheme: IconThemeData(color: p.onContainer),
      unselectedIconTheme: IconThemeData(color: p.muted),
      selectedLabelTextStyle: textTheme.labelLarge?.copyWith(
        color: p.onContainer,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: textTheme.labelLarge?.copyWith(color: p.muted),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.primary,
      foregroundColor: p.onPrimary,
      extendedTextStyle: textTheme.labelLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
    listTileTheme: ListTileThemeData(
      iconColor: p.muted,
      selectedColor: p.onContainer,
      selectedTileColor: p.container,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: p.boxLine,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.primary,
      linearTrackColor: p.container,
      circularTrackColor: p.container,
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide(color: p.boxLine, width: 2),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: selected(p.container, p.surface),
        foregroundColor: selected(p.onContainer, p.text),
        side: WidgetStatePropertyAll(lineSide),
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.text,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: p.bg),
      actionTextColor: other.primary,
    ),
  );
}
