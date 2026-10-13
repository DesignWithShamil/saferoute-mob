import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'state_views.dart';

/// Fade + slide-up entrance. Purely visual; plays once when first built.
class SrFadeIn extends StatelessWidget {
  const SrFadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 520),
    this.offset = 22,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offset;

  @override
  Widget build(BuildContext context) {
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

/// Gentle endless up/down float (used for the hero bus icon).
class SrFloating extends StatefulWidget {
  const SrFloating({super.key, required this.child, this.distance = 8, this.period = const Duration(milliseconds: 2400)});
  final Widget child;
  final double distance;
  final Duration period;

  @override
  State<SrFloating> createState() => _SrFloatingState();
}

class _SrFloatingState extends State<SrFloating> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period)..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = Curves.easeInOutSine.transform(_c.value);
          return Transform.translate(offset: Offset(0, -widget.distance * t), child: child);
        },
        child: widget.child,
      );
}

/// Aurora palette used by the sign-in / registration pages.
class SrGradients {
  SrGradients._();
  static const teal = Color(0xFF0A9E92);
  static const violet = Color(0xFF6D3BEA);
  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [teal, AppColors.brand, violet],
    stops: [0.0, 0.52, 1.0],
  );
  static const button = LinearGradient(colors: [AppColors.brand, violet]);
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..lineTo(0, h - 30)
      ..quadraticBezierTo(w * 0.25, h + 12, w * 0.55, h - 22)
      ..quadraticBezierTo(w * 0.82, h - 50, w, h - 20)
      ..lineTo(w, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Soft background used by the sign-in / registration pages.
class SrAuthBackground extends StatelessWidget {
  const SrAuthBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE6F6F4), Color(0xFFEFF2FF), Color(0xFFF7F8FC)],
          ),
        ),
        child: child,
      );
}

/// Gradient hero with floating bus, decorative rings and a tagline.
class SrAuthHero extends StatelessWidget {
  const SrAuthHero({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.directions_bus_rounded,
    this.compact = false,
    this.showFeatures = true,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool compact;
  final bool showFeatures;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return ClipPath(
      clipper: _WaveClipper(),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(24, top + (compact ? 14 : 28), 24, compact ? 52 : 62),
        decoration: const BoxDecoration(gradient: SrGradients.hero),
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            Positioned(right: -90, top: -70, child: _ring(190, 0.07)),
            Positioned(left: -80, bottom: -20, child: _ring(140, 0.06)),
            SizedBox(
              width: double.infinity,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (onBack != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InkResponse(
                      onTap: onBack,
                      radius: 26,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      ),
                    ),
                  ),
                SizedBox(height: onBack != null ? 6 : 0),
                SrFloating(
                  child: Container(
                    width: compact ? 70 : 88,
                    height: compact ? 70 : 88,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(compact ? 22 : 28),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 12))],
                    ),
                    child: Icon(icon, size: compact ? 38 : 48, color: Colors.white),
                  ),
                ),
                SizedBox(height: compact ? 14 : 18),
                SrFadeIn(
                  delay: const Duration(milliseconds: 150),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: compact ? 24 : 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SrFadeIn(
                  delay: const Duration(milliseconds: 260),
                  child: Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, height: 1.35, color: Colors.white.withValues(alpha: 0.86)),
                  ),
                ),
                if (showFeatures) ...[
                  const SizedBox(height: 18),
                  SrFadeIn(
                    delay: const Duration(milliseconds: 380),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: const [
                        _FeaturePill(icon: Icons.my_location_rounded, label: 'Live tracking'),
                        _FeaturePill(icon: Icons.verified_user_rounded, label: 'Safe pickup'),
                        _FeaturePill(icon: Icons.notifications_active_rounded, label: 'Instant alerts'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _ring(double size, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: alpha * 2), width: 1.5),
          color: Colors.white.withValues(alpha: alpha),
        ),
      );
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        ),
      );
}

/// Elevated white panel used for the auth forms.
class SrFormPanel extends StatelessWidget {
  const SrFormPanel({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.07), blurRadius: 28, offset: const Offset(0, 14))],
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
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down && enabled ? 0.97 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: enabled || widget.busy
                ? SrGradients.button
                : LinearGradient(colors: [AppColors.brand.withValues(alpha: 0.4), SrGradients.violet.withValues(alpha: 0.4)]),
            boxShadow: enabled
                ? [BoxShadow(color: SrGradients.violet.withValues(alpha: 0.30), blurRadius: 16, offset: const Offset(0, 8))]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: enabled ? widget.onPressed : null,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
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
                            Text(widget.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
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
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.ink, Color(0xFF1B2A6B), AppColors.brand],
          ),
          boxShadow: [BoxShadow(color: AppColors.brand.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    first.isEmpty ? greeting : '$greeting, $first',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.2),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('EEEE, d MMM y').format(_now),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14)),
              child: Text(
                DateFormat('h:mm a').format(_now),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
