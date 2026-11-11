import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Amarelo forte + preto, fundo claro, botões em pílula e fonte grossa.
const brandYellow = Color(0xFFFFCC00);
const brandYellowSoft = Color(0xFFFFF3BF);
const ink = Color(0xFF1A1A1A);
const inkSoft = Color(0xFF5C5C5C);
const canvas = Color(0xFFF5F5F5);
const line = Color(0xFFE6E6E6);
const danger = Color(0xFFD93025);
const dangerSoft = Color(0xFFFDE7E5);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: brandYellow).copyWith(
    primary: brandYellow,
    onPrimary: ink,
    primaryContainer: brandYellow,
    onPrimaryContainer: ink,
    secondary: ink,
    onSecondary: Colors.white,
    secondaryContainer: brandYellowSoft,
    onSecondaryContainer: ink,
    surface: Colors.white,
    onSurface: ink,
    onSurfaceVariant: inkSoft,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Colors.white,
    surfaceContainer: Colors.white,
    surfaceContainerHigh: canvas,
    surfaceContainerHighest: line,
    outline: const Color(0xFFBDBDBD),
    outlineVariant: line,
    error: danger,
    errorContainer: dangerSoft,
    onErrorContainer: danger,
  );

  final family = GoogleFonts.poppins().fontFamily;
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: family,
  ).textTheme.apply(bodyColor: ink, displayColor: ink);
  final text = base.copyWith(
    headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
    titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w700),
  );

  const pill = StadiumBorder();
  final buttonText = text.labelLarge?.copyWith(fontSize: 15);

  return ThemeData(
    useMaterial3: true,
    fontFamily: family,
    colorScheme: scheme,
    textTheme: text,
    scaffoldBackgroundColor: canvas,
    appBarTheme: AppBarTheme(
      backgroundColor: brandYellow,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge?.copyWith(fontSize: 22),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: brandYellow,
        foregroundColor: ink,
        disabledBackgroundColor: line,
        disabledForegroundColor: inkSoft,
        shape: pill,
        minimumSize: const Size(0, 50),
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        side: const BorderSide(color: ink, width: 1.5),
        shape: pill,
        minimumSize: const Size(0, 50),
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ink,
        shape: pill,
        textStyle: buttonText?.copyWith(decoration: TextDecoration.underline),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: ink,
      foregroundColor: brandYellow,
      shape: pill,
      elevation: 2,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: brandYellow,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => text.labelMedium?.copyWith(
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w500,
        ),
      ),
      iconTheme: const WidgetStatePropertyAll(IconThemeData(color: ink)),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? brandYellow : null,
      ),
      checkColor: const WidgetStatePropertyAll(ink),
      side: const BorderSide(color: Color(0xFF9E9E9E), width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? ink : Colors.white,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? brandYellow : line,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: ink,
        selectedForegroundColor: brandYellow,
        foregroundColor: ink,
        side: const BorderSide(color: ink, width: 1.5),
        textStyle: buttonText,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      shape: const StadiumBorder(),
      labelStyle: text.labelLarge,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ink, width: 2),
      ),
      floatingLabelStyle: const TextStyle(
        color: ink,
        fontWeight: FontWeight.w600,
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: ink,
      selectionColor: brandYellowSoft,
      selectionHandleColor: ink,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: ink,
      contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
      actionTextColor: brandYellow,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: line,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: const DividerThemeData(color: line),
  );
}
