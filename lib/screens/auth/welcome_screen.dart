import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/ethiyo_brand.dart';
import '../../widgets/sr_animations.dart';
import '../../widgets/state_views.dart';

/// First screen for signed-out users: the Ethiyo scene, logo and tagline with
/// a single round button into sign-in. Purely presentational; authentication
/// still happens on the login screen.
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
                Positioned(
                  top: insets.top + 36,
                  left: 24,
                  right: 24,
                  child: Column(
                    children: [
                      SrFadeIn(child: const EthiyoLogoCard(width: 190)),
                      const SizedBox(height: 18),
                      SrFadeIn(
                        delay: const Duration(milliseconds: 100),
                        child: const Text(
                          'Safe School Transport\nfor a Brighter Tomorrow',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: Colors.white,
                            shadows: [Shadow(color: Color(0x800B2A5B), blurRadius: 12, offset: Offset(0, 2))],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(left: 0, right: 0, bottom: 0, child: _BottomSheet(bottomInset: insets.bottom, onContinue: onContinue)),
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
  const _BottomSheet({required this.bottomInset, required this.onContinue});
  final double bottomInset;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => ClipPath(
        clipper: _SheetTopClipper(),
        child: Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(28, 48, 24, bottomInset + 24),
          child: Row(
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
        ),
      );
}
