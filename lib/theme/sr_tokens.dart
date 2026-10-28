import 'package:flutter/widgets.dart';

/// SafeRoute design tokens. Spacing, radii, sizes and motion live here so that
/// screens never invent one-off values. Colours live in `AppColors`
/// (widgets/state_views.dart) and text styles in `SafeRouteTheme`.
class SrSpace {
  SrSpace._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  /// Horizontal page gutter that grows a little on larger screens.
  static double gutter(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 600) return 28;
    if (w >= 380) return 20;
    return 16;
  }
}

class SrRadius {
  SrRadius._();
  static const chip = 10.0;
  static const input = 14.0;
  static const button = 14.0;
  static const card = 18.0;
  static const panel = 24.0;
  static const sheet = 28.0;
}

class SrSize {
  SrSize._();

  /// Minimum comfortable touch target (Material / WCAG guidance).
  static const touch = 48.0;
  static const buttonHeight = 52.0;
  static const inputHeight = 54.0;
  static const iconSm = 18.0;
  static const iconMd = 22.0;
  static const iconLg = 28.0;

  /// Widest content column on tablets; phones are never constrained by it.
  static const maxContentWidth = 720.0;
  static const maxFormWidth = 480.0;
}

class SrMotion {
  SrMotion._();
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 300);
  static const curve = Curves.easeOutCubic;

  /// True when the user asked the OS to reduce motion.
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Returns [d], or zero when motion is reduced.
  static Duration of(BuildContext context, Duration d) => reduced(context) ? Duration.zero : d;
}
