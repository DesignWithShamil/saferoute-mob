import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/sr_tokens.dart';
import 'ethiyo_brand.dart';
import 'state_views.dart';

/// Fade + slide-up entrance. Purely visual; plays once when first built.
class SrFadeIn extends StatelessWidget {
  const SrFadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 300),
    this.offset = 14,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offset;

  @override
  Widget build(BuildContext context) {
    if (SrMotion.reduced(context)) return child;
    final total = duration + delay;
    final start = total.inMilliseconds == 0 ? 0.0 : delay.inMilliseconds / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - t) * offset), child: child),
      ),
      child: child,
    );
  }
}

/// Gentle one-time "settle" for the hero icon. (Previously an endless float;
/// continuous animation drains budget phones and distracts, so it now plays
/// once and respects reduced-motion settings.)
class SrFloating extends StatelessWidget {
  const SrFloating({super.key, required this.child, this.distance = 8, this.period = const Duration(milliseconds: 600)});
  final Widget child;
  final double distance;
  final Duration period;

  @override
  Widget build(BuildContext context) {
    if (SrMotion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: period,
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Transform.translate(offset: Offset(0, -distance * t), child: child),
      child: child,
    );
  }
}

/// Brand gradients for the auth screens and featured buttons: navy to royal
/// blue, with a restrained teal edge. No extra hues.
class SrGradients {
  SrGradients._();
  static const teal = AppColors.teal;
  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.brandDeep, AppColors.brand, AppColors.teal],
    stops: [0.0, 0.62, 1.0],
  );
  static const button = LinearGradient(colors: [AppColors.brand, AppColors.brandDeep]);
}

/// Clips the hero so the white sheet below bulges up in the centre.
class _SheetClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..lineTo(w, 0)
      ..lineTo(w, h)
      ..quadraticBezierTo(w / 2, h - 60, 0, h)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Page background for the auth screens: clean white that fades to a faint sky.
class SrAuthBackground extends StatelessWidget {
  const SrAuthBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.white, AppColors.brandTint],
            stops: [0.0, 0.7, 1.0],
          ),
        ),
        child: child,
      );
}

/// Photographic header for sign-in / registration / reset pages: the Ethiyo
/// scene with a curved sheet edge. [showLogo] adds the logo card (sign-in);
/// otherwise [title] and [subtitle] sit over the scene (inner auth pages).
class SrAuthHero extends StatelessWidget {
  const SrAuthHero({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.directions_bus_rounded,
    this.compact = false,
    this.showFeatures = true,
    this.onBack,
    this.showLogo = false,
  });

  final String title;
  final String subtitle;

  /// Kept for API compatibility; the scene replaces the icon tile.
  final IconData icon;
  final bool compact;
  final bool showFeatures;
  final VoidCallback? onBack;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final minHeight = (showLogo ? 350.0 : (compact ? 220.0 : 300.0)) + top;
    return ClipPath(
      clipper: _SheetClipper(),
      child: Stack(
        children: [
          const Positioned.fill(child: EthiyoHeroImage(alignment: Alignment(0, 0.8))),
          // Gentle scrim keeps white text legible without hiding the scene.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.brandDeep.withValues(alpha: showLogo ? 0.30 : 0.55),
                    AppColors.brandDeep.withValues(alpha: 0.0),
                    AppColors.brandDeep.withValues(alpha: showLogo ? 0.0 : 0.35),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, top + 14, 24, 56),
              child: showLogo ? _logoLayout() : _titleLayout(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoLayout() => Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          SrFadeIn(child: const EthiyoLogoCard()),
          const SizedBox(height: 14),
          SrFadeIn(
            delay: const Duration(milliseconds: 80),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                shadows: [Shadow(color: Color(0x660B2A5B), blurRadius: 8, offset: Offset(0, 2))],
              ),
            ),
          ),
        ],
      );

  Widget _titleLayout() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (onBack != null)
            Material(
              color: Colors.white.withValues(alpha: 0.9),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onBack,
                child: const SizedBox(
                  width: SrSize.touch,
                  height: SrSize.touch,
                  child: Tooltip(message: 'Back', child: Icon(Icons.arrow_back_rounded, color: AppColors.brandDeep)),
                ),
              ),
            )
          else
            const SizedBox(height: SrSize.touch),
          const SizedBox(height: 24),
          SrFadeIn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 28,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: Colors.white,
                    shadows: [Shadow(color: Color(0x660B2A5B), blurRadius: 10, offset: Offset(0, 2))],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: Colors.white,
                    shadows: [Shadow(color: Color(0x660B2A5B), blurRadius: 8, offset: Offset(0, 1))],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

/// Soft floating panel used for the auth forms.
class SrFormPanel extends StatelessWidget {
  const SrFormPanel({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(SrRadius.panel),
          boxShadow: [BoxShadow(color: AppColors.brandDeep.withValues(alpha: 0.10), blurRadius: 28, offset: const Offset(0, 12))],
        ),
        child: child,
      );
}

/// Primary call-to-action with a loading state and a press-scale effect.
class SrPrimaryButton extends StatefulWidget {
  const SrPrimaryButton({super.key, required this.label, required this.onPressed, this.busy = false, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  @override
  State<SrPrimaryButton> createState() => _SrPrimaryButtonState();
}

class _SrPrimaryButtonState extends State<SrPrimaryButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    final radius = BorderRadius.circular(SrRadius.button + 2);
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.busy ? '${widget.label}, please wait' : widget.label,
      excludeSemantics: true,
      child: Listener(
        onPointerDown: (_) => setState(() => _down = true),
        onPointerUp: (_) => setState(() => _down = false),
        onPointerCancel: (_) => setState(() => _down = false),
        child: AnimatedScale(
          scale: _down && enabled ? 0.98 : 1,
          duration: SrMotion.of(context, const Duration(milliseconds: 110)),
          curve: Curves.easeOut,
          child: Container(
            // minHeight (not height) so the label can grow with large system text.
            constraints: const BoxConstraints(minHeight: SrSize.buttonHeight + 4),
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: enabled || widget.busy
                  ? SrGradients.button
                  : LinearGradient(colors: [AppColors.brand.withValues(alpha: 0.4), AppColors.brandDeep.withValues(alpha: 0.4)]),
              boxShadow: enabled
                  ? [BoxShadow(color: AppColors.brand.withValues(alpha: 0.26), blurRadius: 14, offset: const Offset(0, 6))]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: radius,
                onTap: enabled ? widget.onPressed : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: SrMotion.of(context, SrMotion.base),
                      child: widget.busy
                          ? const SizedBox(
                              key: ValueKey('busy'),
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                            )
                          : Row(
                              key: const ValueKey('label'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.label,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                                  ),
                                ),
                                if (widget.icon != null) ...[
                                  const SizedBox(width: 8),
                                  Icon(widget.icon, color: Colors.white, size: 20),
                                ],
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Greeting + live clock + date header shown at the top of the home tabs.
class SrClockHeader extends StatefulWidget {
  const SrClockHeader({super.key, this.name});
  final String? name;

  @override
  State<SrClockHeader> createState() => _SrClockHeaderState();
}

class _SrClockHeaderState extends State<SrClockHeader> {
  late DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = _now.hour;
    final greeting = h < 12 ? 'Good morning' : (h < 17 ? 'Good afternoon' : 'Good evening');
    final icon = h < 12 ? Icons.wb_sunny_rounded : (h < 17 ? Icons.wb_twilight_rounded : Icons.nights_stay_rounded);
    final first = (widget.name ?? '').trim().split(' ').first;
    return SrFadeIn(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SrRadius.panel),
          boxShadow: [BoxShadow(color: AppColors.brandDeep.withValues(alpha: 0.24), blurRadius: 22, offset: const Offset(0, 10))],
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: EthiyoHeroImage(alignment: Alignment(0, 0.6), cacheWidth: 800)),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppColors.brandDeep.withValues(alpha: 0.94),
                      AppColors.brandDeep.withValues(alpha: 0.62),
                      AppColors.brandDeep.withValues(alpha: 0.12),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(color: AppColors.sun, borderRadius: BorderRadius.circular(16)),
                    child: Icon(icon, color: AppColors.brandDeep, size: 25),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          first.isEmpty ? greeting : '$greeting, $first',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.2, height: 1.2),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          DateFormat('EEEE, d MMM y').format(_now),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: Text(
                      DateFormat('h:mm a').format(_now),
                      style: const TextStyle(color: AppColors.brandDeep, fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
