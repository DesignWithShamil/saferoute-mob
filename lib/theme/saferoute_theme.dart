import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/state_views.dart';

/// SafeRoute visual language: deep-ink surfaces, a vivid royal-blue brand,
/// soft floating cards and generously rounded controls.
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
      primaryContainer: const Color(0xFFE3EAFF),
      onPrimaryContainer: AppColors.brandDeep,
      secondaryContainer: const Color(0xFFE3EAFF),
      onSecondaryContainer: AppColors.brandDeep,
      surface: Colors.white,
      onSurface: _ink,
      onSurfaceVariant: AppColors.slate,
      outline: const Color(0xFF9AA4B8),
      outlineVariant: _border,
      error: AppColors.red,
      surfaceContainerHighest: const Color(0xFFEAEEF6),
    );

    RoundedRectangleBorder rr(double r) => RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      fontFamily: '.AppleSystemUIFont',
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.4, color: _ink),
        titleMedium: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2, color: _ink),
        titleSmall: TextStyle(fontWeight: FontWeight.w700, color: _ink),
        bodyMedium: TextStyle(color: _ink, height: 1.35),
        bodySmall: TextStyle(color: AppColors.slate, height: 1.35),
        labelSmall: TextStyle(color: AppColors.slate, fontWeight: FontWeight.w600),
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
        backgroundColor: _ink,
        indicatorColor: Colors.white.withValues(alpha: 0.14),
        iconTheme: WidgetStateProperty.resolveWith((states) =>
            IconThemeData(color: states.contains(WidgetState.selected) ? Colors.white : Colors.white54)),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected ? Colors.white : Colors.white54,
          );
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: _ink.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: _border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(88, 54),
          elevation: 0,
          shape: rr(16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: rr(12),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 50),
          foregroundColor: AppColors.brand,
          backgroundColor: Colors.white,
          side: BorderSide(color: AppColors.brand.withValues(alpha: 0.35), width: 1.2),
          shape: rr(16),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: seed, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.red)),
        focusedErrorBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.red, width: 1.8)),
        labelStyle: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.slate),
        hintStyle: TextStyle(color: AppColors.slate.withValues(alpha: 0.7)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFFE3EAFF),
        side: const BorderSide(color: _border),
        shape: rr(14),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, color: _ink),
        secondaryLabelStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.brandDeep),
        showCheckmark: false,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _ink,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        actionTextColor: const Color(0xFF9DB6FF),
        shape: rr(16),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: rr(26),
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
        iconColor: AppColors.brand,
        titleTextStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: _ink),
        subtitleTextStyle: const TextStyle(fontSize: 13, color: AppColors.slate, height: 1.3),
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
          selectedBackgroundColor: const Color(0xFFE3EAFF),
          selectedForegroundColor: AppColors.brandDeep,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.brand,
        unselectedLabelColor: AppColors.slate,
        indicatorColor: AppColors.brand,
        labelStyle: TextStyle(fontWeight: FontWeight.w800),
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
