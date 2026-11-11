import 'package:flutter/material.dart';

/// Screen size breakpoints & adaptive layout helpers for SafeRoute mobile app.
/// Ensures all screens adapt seamlessly across compact phones, standard devices,
/// tall aspect-ratio displays (19.5:9, 20:9, 21:9), foldables, and tablets.
class SrResponsive {
  SrResponsive._(this.context);

  final BuildContext context;

  static SrResponsive of(BuildContext context) => SrResponsive._(context);

  Size get size => MediaQuery.sizeOf(context);
  double get width => size.width;
  double get height => size.height;
  EdgeInsets get padding => MediaQuery.paddingOf(context);
  EdgeInsets get viewInsets => MediaQuery.viewInsetsOf(context);
  bool get isKeyboardOpen => viewInsets.bottom > 0;

  // --- Width Breakpoints ---
  /// Narrow phones (e.g. iPhone SE 1st gen, smaller Androids < 360dp)
  bool get isCompactWidth => width < 360;

  /// Standard smartphone widths (360dp to 599dp)
  bool get isStandardWidth => width >= 360 && width < 600;

  /// Tablets, foldable main displays or desktop/web (>= 600dp)
  bool get isTablet => width >= 600;

  // --- Height Breakpoints ---
  /// Short viewports (< 680dp: small phones, split screen, landscape)
  bool get isShortScreen => height < 680;

  /// Standard smartphone height range (680dp to 859dp: iPhone 12/13/14/15, Galaxy S21/S22/S23)
  bool get isStandardHeight => height >= 680 && height < 860;

  /// Modern tall flagships (>= 860dp: Pixel 7/8/9 Pro, Galaxy Ultra, iPhone Plus / Pro Max)
  bool get isTallScreen => height >= 860;

  /// True when device is rotated in landscape
  bool get isLandscape => width > height;

  // --- Adaptive Sizing & Metrics ---

  /// Horizontal margin / page gutter
  double get horizontalGutter {
    if (isTablet) return 32.0;
    if (isCompactWidth) return 16.0;
    return 22.0;
  }

  /// Adaptive hero image height for auth screens (login, forgot password, register)
  double get authHeroHeight {
    if (isLandscape) return (height * 0.38).clamp(130.0, 180.0);
    if (isShortScreen) return (height * 0.28).clamp(160.0, 210.0);
    if (isTallScreen) return (height * 0.34).clamp(270.0, 320.0);
    return (height * 0.31).clamp(220.0, 270.0);
  }

  /// Adaptive brand logo width for auth forms
  double get authLogoWidth {
    if (isCompactWidth || isShortScreen) return 145.0;
    if (isTablet) return 195.0;
    return 170.0;
  }

  /// Adaptive welcome screen hero logo width
  double get welcomeLogoWidth {
    if (isCompactWidth || isShortScreen) return 190.0;
    if (isTablet) return 260.0;
    return 235.0;
  }

  /// Maximum form card width to ensure elegant presentation on tablets & foldables
  double get maxFormWidth => 480.0;

  /// Maximum general content width on larger screens
  double get maxContentWidth => 720.0;
}

/// Convenience extension on [BuildContext] to access responsive helpers easily.
extension SrResponsiveContext on BuildContext {
  SrResponsive get responsive => SrResponsive.of(this);
}

