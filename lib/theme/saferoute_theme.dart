import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/state_views.dart';
import 'sr_tokens.dart';

/// SafeRoute visual language: navy + royal blue brand with a teal accent,
/// calm neutral surfaces, softly rounded cards and generous touch targets.
/// Spacing/radius/motion tokens are in `sr_tokens.dart`, colours in `AppColors`.
class SafeRouteTheme {
  SafeRouteTheme._();

  static const _ink = AppColors.ink;
  static const _border = AppColors.border;

  static ThemeData light() {
    const seed = AppColors.brand;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.brand,
      onPrimary: Colors.white,
      primaryContainer: AppColors.brandTint,
      onPrimaryContainer: AppColors.brandDeep,
      secondaryContainer: AppColors.brandTint,
      secondary: AppColors.teal,
      onSecondary: Colors.white,
      tertiary: AppColors.info,
      onSecondaryContainer: AppColors.brandDeep,
      surface: Colors.white,
      onSurface: _ink,
      onSurfaceVariant: AppColors.slate,
      outline: const Color(0xFF8795AB),
      outlineVariant: _border,
      error: AppColors.red,
      surfaceContainerHighest: const Color(0xFFEAEFF7),
    );

    RoundedRectangleBorder rr(double r) => RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      // Platform default (Roboto on Android, SF on iOS): crisp, fast, and
      // covers Malayalam and other scripts through system fallback.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      textTheme: const TextTheme(
        // Display heading
        headlineMedium: TextStyle(fontSize: 28, height: 1.2, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: _ink),
        headlineSmall: TextStyle(fontSize: 24, height: 1.25, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: _ink),
        // Screen title
        titleLarge: TextStyle(fontSize: 20, height: 1.3, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: _ink),
        // Section heading / card title
        titleMedium: TextStyle(fontSize: 17, height: 1.3, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: _ink),
        titleSmall: TextStyle(fontSize: 15, height: 1.3, fontWeight: FontWeight.w700, color: _ink),
        // Body
        bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: _ink),
        bodyMedium: TextStyle(fontSize: 14.5, height: 1.4, color: _ink),
        bodySmall: TextStyle(fontSize: 13, height: 1.4, color: AppColors.slate),
        // Labels / buttons / captions
        labelLarge: TextStyle(fontSize: 15, height: 1.2, fontWeight: FontWeight.w700),
        labelMedium: TextStyle(fontSize: 13, height: 1.2, fontWeight: FontWeight.w600, color: AppColors.slate),
        labelSmall: TextStyle(fontSize: 12, height: 1.25, fontWeight: FontWeight.w600, color: AppColors.slate),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _ink,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleSpacing: 4,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: _ink,
        ),
        iconTheme: IconThemeData(color: _ink),
        actionsIconTheme: IconThemeData(color: _ink),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 68,
        backgroundColor: AppColors.brandDeep,
        indicatorColor: Colors.white.withValues(alpha: 0.14),
        iconTheme: WidgetStateProperty.resolveWith((states) =>
            IconThemeData(color: states.contains(WidgetState.selected) ? Colors.white : Colors.white70)),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected ? Colors.white : Colors.white70,
          );
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: _ink.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SrRadius.card),
          side: const BorderSide(color: _border),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(SrSize.touch, SrSize.touch)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(88, SrSize.buttonHeight),
          elevation: 0,
          shape: rr(SrRadius.button),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.1),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, SrSize.touch),
          shape: rr(12),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, SrSize.buttonHeight - 2),
          foregroundColor: AppColors.brand,
          backgroundColor: Colors.white,
          side: BorderSide(color: AppColors.brand.withValues(alpha: 0.35), width: 1.2),
          shape: rr(SrRadius.button),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        errorMaxLines: 3,
        helperMaxLines: 3,
        errorStyle: const TextStyle(fontSize: 12.5, height: 1.3, fontWeight: FontWeight.w600, color: AppColors.red),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(SrRadius.input), borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(SrRadius.input), borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SrRadius.input),
          borderSide: const BorderSide(color: seed, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(SrRadius.input), borderSide: const BorderSide(color: AppColors.red)),
        focusedErrorBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(SrRadius.input), borderSide: const BorderSide(color: AppColors.red, width: 1.8)),
        labelStyle: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.slate),
        hintStyle: const TextStyle(color: Color(0xFF8795AB)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.brandTint,
        side: const BorderSide(color: _border),
        shape: rr(SrRadius.chip + 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, color: _ink),
        secondaryLabelStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.brandDeep),
        showCheckmark: false,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _ink,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        actionTextColor: const Color(0xFF9DBBFF),
        shape: rr(16),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(SrRadius.sheet)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: rr(SrRadius.panel),
        titleTextStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: _ink),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.only(topRight: Radius.circular(28), bottomRight: Radius.circular(28))),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minVerticalPadding: 8,
        minTileHeight: SrSize.touch,
        iconColor: AppColors.brand,
        titleTextStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: _ink),
        subtitleTextStyle: const TextStyle(fontSize: 13.5, color: AppColors.slate, height: 1.35),
        shape: rr(16),
      ),
      dividerTheme: const DividerThemeData(color: _border, space: 1, thickness: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.brand),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.brand : const Color(0xFFC9D0DF)),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: rr(14),
          side: const BorderSide(color: _border),
          selectedBackgroundColor: AppColors.brandTint,
          selectedForegroundColor: AppColors.brandDeep,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.brand,
        unselectedLabelColor: AppColors.slate,
        indicatorColor: AppColors.brand,
        labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
        dividerColor: _border,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: rr(20),
      ),
    );
  }
}
