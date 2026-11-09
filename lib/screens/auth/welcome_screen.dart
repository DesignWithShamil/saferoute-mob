import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/ethiyo_brand.dart';
import '../../widgets/sr_animations.dart';
import '../../widgets/sr_transitions.dart';
import '../../widgets/state_views.dart';
import 'user_tutorial_screen.dart';

/// First screen for signed-out users: the Ethiyo scene and centered logo with
/// a single round button into sign-in and quick access to the user tutorial.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: AppColors.brandDeep,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const EthiyoHeroImage(alignment: Alignment.center, cacheWidth: 1100),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                      colors: [AppColors.brandDeep.withValues(alpha: 0.45), AppColors.brandDeep.withValues(alpha: 0)],
                    ),
                  ),
                ),
                // Top "How to Use" tutorial button
                Positioned(
                  top: insets.top + 12,
                  right: 20,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.black.withValues(alpha: 0.28),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    ),
                    icon: const Icon(Icons.help_outline_rounded, size: 18),
                    label: const Text('How to Use', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    onPressed: () => Navigator.of(context).push(
                      srFadeRoute(
                        UserTutorialScreen(
                          isStandalone: true,
                          onFinished: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                  ),
                ),
                // Transparent, centered Ethiyo Logo without any white background card
                Positioned(
                  top: insets.top + 56,
                  left: 24,
                  right: 24,
                  child: const Center(
                    child: SrFadeIn(
                      child: EthiyoLogo(width: 230),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _BottomSheet(
                    bottomInset: insets.bottom,
                    onContinue: onContinue,
                    onOpenTutorial: () => Navigator.of(context).push(
                      srFadeRoute(
                        UserTutorialScreen(
                          isStandalone: true,
                          onFinished: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetTopClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 40)
    ..quadraticBezierTo(size.width / 2, -12, size.width, 40)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _BottomSheet extends StatelessWidget {
  const _BottomSheet({
    required this.bottomInset,
    required this.onContinue,
    required this.onOpenTutorial,
  });

  final double bottomInset;
  final VoidCallback onContinue;
  final VoidCallback onOpenTutorial;

  @override
  Widget build(BuildContext context) => ClipPath(
        clipper: _SheetTopClipper(),
        child: Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(28, 44, 24, bottomInset + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('For parents, drivers & helpers', style: TextStyle(fontSize: 13.5, color: AppColors.slate)),
                        SizedBox(height: 4),
                        Text(
                          'Live tracking · Safe pickup · Instant alerts',
                          style: TextStyle(fontSize: 16, height: 1.3, fontWeight: FontWeight.w800, color: AppColors.brandDeep),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Semantics(
                    button: true,
                    label: 'Get started',
                    excludeSemantics: true,
                    child: Material(
                      color: Colors.transparent,
                      child: Ink(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.heroGradient,
                          boxShadow: [BoxShadow(color: AppColors.brand.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
                        ),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onContinue,
                          child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 28),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: onOpenTutorial,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book_rounded, size: 16, color: AppColors.brand),
                      SizedBox(width: 6),
                      Text(
                        'New to SafeRoute? View User Guide Tutorial',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brand,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
