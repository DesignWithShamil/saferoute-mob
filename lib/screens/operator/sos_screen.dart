import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/sr_animations.dart';
import '../../widgets/state_views.dart';
import 'attendance_roster.dart';

/// React `/driver/emergency` and `/helper/emergency`.
class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = (box.maxWidth * 0.5).clamp(140.0, 210.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight - 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SrFadeIn(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded, color: AppColors.red, size: 16),
                            SizedBox(width: 6),
                            Text('EMERGENCY ONLY',
                                style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w800, fontSize: 11.5, letterSpacing: 0.8)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('Emergency SOS',
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.6, color: AppColors.ink)),
                      const SizedBox(height: 8),
                      const Text(
                        'Only trigger for a genuine emergency (breakdown, accident, medical). This alerts school admins and parents.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.slate, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  height: size + 90,
                  width: size + 90,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      for (final delay in const [0.0, 0.5])
                        AnimatedBuilder(
                          animation: _pulse,
                          builder: (context, _) {
                            final t = (_pulse.value + delay) % 1.0;
                            return Opacity(
                              opacity: (1 - t) * 0.35,
                              child: Container(
                                width: size + 90 * t,
                                height: size + 90 * t,
                                decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
                              ),
                            );
                          },
                        ),
                      Container(
                        height: size,
                        width: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            center: Alignment(-0.3, -0.4),
                            colors: [Color(0xFFFF6B6E), AppColors.red, Color(0xFFB0171A)],
                            stops: [0, 0.55, 1],
                          ),
                          boxShadow: [BoxShadow(color: AppColors.red.withValues(alpha: 0.5), blurRadius: 28, offset: const Offset(0, 12))],
                        ),
                        child: Material(
                          type: MaterialType.transparency,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              HapticFeedback.heavyImpact();
                              showSosFlow(context);
                            },
                            child: const Center(
                              child: Text('SOS',
                                  style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
