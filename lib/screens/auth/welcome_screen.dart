import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/ethiyo_brand.dart';
import '../../widgets/state_views.dart';

/// First screen for signed-out users: cinematic Ethiyo scene entrance with
/// floating logo animation, smooth sheet slide-up, and pulsing action button.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.onContinue});
  final VoidCallback onContinue;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _pulseController;

  late final Animation<double> _bgScale;
  late final Animation<double> _bgFade;
  late final Animation<Offset> _logoSlide;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _sheetSlide;
  late final Animation<double> _sheetFade;
  late final Animation<double> _buttonScale;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    // Staggered cinematic entrance curves
    _bgScale = Tween<double>(begin: 1.10, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _bgFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.40, curve: Curves.easeIn),
      ),
    );

    _logoSlide = Tween<Offset>(begin: const Offset(0, -36), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.12, 0.75, curve: Curves.easeOutBack),
      ),
    );

    _logoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.12, 0.75, curve: Curves.easeOutBack),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.10, 0.55, curve: Curves.easeOut),
      ),
    );

    _sheetSlide = Tween<Offset>(begin: const Offset(0, 90), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.30, 0.95, curve: Curves.easeOutCubic),
      ),
    );

    _sheetFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.30, 0.70, curve: Curves.easeOut),
      ),
    );

    _buttonScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.55, 1.0, curve: Curves.elasticOut),
      ),
    );

    _entranceController.forward().then((_) {
      if (mounted) {
        _pulseController.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

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
                // 1. Animated Hero background with scale-in + fade
                AnimatedBuilder(
                  animation: _entranceController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _bgFade.value,
                      child: Transform.scale(
                        scale: _bgScale.value,
                        child: child,
                      ),
                    );
                  },
                  child: const EthiyoHeroImage(alignment: Alignment.center, cacheWidth: 1100),
                ),

                // Top gradient scrim
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                      colors: [
                        AppColors.brandDeep.withValues(alpha: 0.50),
                        AppColors.brandDeep.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),

                // 2. Animated Floating Logo entrance
                Positioned(
                  top: insets.top + 50,
                  left: 24,
                  right: 24,
                  child: AnimatedBuilder(
                    animation: _entranceController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _logoFade.value,
                        child: Transform.translate(
                          offset: _logoSlide.value,
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: const Center(
                      child: EthiyoLogo(width: 240),
                    ),
                  ),
                ),

                // 3. Animated Bottom curved sheet sliding up smoothly
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedBuilder(
                    animation: _entranceController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _sheetFade.value,
                        child: Transform.translate(
                          offset: _sheetSlide.value,
                          child: child,
                        ),
                      );
                    },
                    child: _AnimatedBottomSheet(
                      bottomInset: insets.bottom,
                      buttonScaleAnimation: _buttonScale,
                      pulseAnimation: _pulseController,
                      onContinue: widget.onContinue,
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

class _AnimatedBottomSheet extends StatelessWidget {
  const _AnimatedBottomSheet({
    required this.bottomInset,
    required this.buttonScaleAnimation,
    required this.pulseAnimation,
    required this.onContinue,
  });

  final double bottomInset;
  final Animation<double> buttonScaleAnimation;
  final Animation<double> pulseAnimation;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => ClipPath(
        clipper: _SheetTopClipper(),
        child: Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(28, 44, 24, bottomInset + 24),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'For parents, drivers & helpers',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Live tracking · Safe pickup · Instant alerts',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandDeep,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Animated Pulsing Next Button
              AnimatedBuilder(
                animation: Listenable.merge([buttonScaleAnimation, pulseAnimation]),
                builder: (context, child) {
                  final entranceScale = buttonScaleAnimation.value;
                  // Subtle breathing scale between 1.0 and 1.06
                  final pulseScale = 1.0 + (pulseAnimation.value * 0.06);
                  return Transform.scale(
                    scale: entranceScale * pulseScale,
                    child: child,
                  );
                },
                child: Semantics(
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
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.brand.withValues(alpha: 0.40),
                            blurRadius: 18,
                            spreadRadius: 2,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onContinue,
                        child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
