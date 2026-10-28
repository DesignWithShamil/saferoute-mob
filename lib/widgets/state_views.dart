import 'package:flutter/material.dart';

import '../theme/sr_tokens.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label, this.branded = false, this.skeleton = false});
  final String? label;
  final bool branded;

  /// Show placeholder rows instead of a spinner (use for list screens).
  final bool skeleton;

  @override
  Widget build(BuildContext context) {
    if (skeleton) return SrSkeletonList(label: label);
    if (branded) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.brand, AppColors.brandDeep],
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [BoxShadow(color: AppColors.brand.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: const Icon(Icons.directions_bus_rounded, size: 44, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.brand),
            ),
            if (label != null) ...[
              const SizedBox(height: 16),
              Text(label!, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
            ],
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.brand),
          if (label != null) ...[
            const SizedBox(height: 16),
            Text(label!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(color: AppColors.red.withValues(alpha: 0.10), shape: BoxShape.circle),
                child: const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.red),
              ),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.slate, height: 1.4)),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                FilledButton.tonalIcon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Try again')),
              ],
            ],
          ),
        ),
      );
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.title, this.message});
  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
              child: Icon(icon, size: 38, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.slate, height: 1.4)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Status pill used for trip, stop and attendance statuses. The wording always
/// carries the meaning (colour is only reinforcement) and raw backend codes
/// such as `IN_PROGRESS` are shown in sentence case.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  static String _pretty(String raw) {
    final t = raw.trim();
    if (t.isEmpty || t != t.toUpperCase()) return t;
    final words = t.replaceAll('_', ' ').toLowerCase();
    return words[0].toUpperCase() + words.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final text = _pretty(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 14, color: AppColors.onTint(color))
          else
            Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.onTint(color), fontSize: 12, fontWeight: FontWeight.w700, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

/// SafeRoute colour tokens. Names are kept stable so every screen inherits the
/// palette; only the values below define the brand.
class AppColors {
  AppColors._();

  /// Primary action colour (royal blue).
  static const brand = Color(0xFF2563EB);

  /// Brand navy: headers, hero cards, selected-state text on tints.
  static const brandDeep = Color(0xFF163A70);

  /// Secondary accent (teal).
  static const teal = Color(0xFF0F9D8A);

  /// Primary text (dark navy).
  static const ink = Color(0xFF172B4D);

  /// App background.
  static const bg = Color(0xFFF5F7FB);

  /// Hairlines and card borders.
  static const border = Color(0xFFE2E8F0);

  /// Secondary text. Slightly darker than slate-500 so it keeps 4.5:1
  /// contrast on [bg] as well as on white.
  static const slate = Color(0xFF59687F);

  static const green = Color(0xFF16A34A);
  static const amber = Color(0xFFF59E0B);
  static const red = Color(0xFFDC2626);
  static const info = Color(0xFF0284C7);

  /// Light brand tint for selected chips, icon tiles and highlights.
  static const brandTint = Color(0xFFE8EEFC);

  /// Brand hero gradient for the few featured cards (welcome, profile).
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandDeep, brand],
  );

  /// A readable text colour for [c] on a pale tint of itself. Mid-tone status
  /// colours (green, amber) fail contrast as text, so darken them.
  static Color onTint(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness * 0.62).clamp(0.0, 0.34)).toColor();
  }

  static Color forStatus(String status) => switch (status) {
        'IN_PROGRESS' || 'BOARDED' || 'DEPARTED' || 'DROP_VERIFIED' || 'ACTIVE' => green,
        'STARTED' || 'ARRIVED' || 'PAUSED' || 'NOT_MARKED' || 'SIGNAL_WEAK' || 'STARTING' => amber,
        'EMERGENCY' || 'ABSENT' || 'CANCELLED' || 'ERROR' || 'GPS_OFF' || 'PERMISSION_DENIED' || 'OFFLINE' => red,
        'COMPLETED' || 'DROPPED' || 'APPROVED' => brand,
        _ => slate,
      };
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child, this.title, this.trailing, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => _EnterAnimation(
        child: Card(
        margin: const EdgeInsets.only(bottom: 14),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title!,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3, color: AppColors.ink),
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
                ),
              child,
            ],
          ),
        ),
        ),
      );
}

/// Subtle fade / rise the first time a card appears.
class _EnterAnimation extends StatelessWidget {
  const _EnterAnimation({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (SrMotion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: SrMotion.slow,
      curve: SrMotion.curve,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 10), child: child),
      ),
      child: child,
    );
  }
}

Future<bool> confirmDialog(BuildContext context,
    {required String title, required String message, String confirm = 'Confirm', bool destructive = false}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: AppColors.red) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.red : null,
      behavior: SnackBarBehavior.floating,
    ));
}

/// Placeholder rows shown while a list loads. A single gentle pulse (disabled
/// when the OS asks for reduced motion) keeps the cost low on budget phones.
class SrSkeletonList extends StatefulWidget {
  const SrSkeletonList({super.key, this.count = 6, this.label});
  final int count;
  final String? label;

  @override
  State<SrSkeletonList> createState() => _SrSkeletonListState();
}

class _SrSkeletonListState extends State<SrSkeletonList> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = SrMotion.reduced(context);
    if (reduced && _started) {
      _c.stop();
      _started = false;
    } else if (!reduced && !_started) {
      _c.repeat(reverse: true);
      _started = true;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label ?? 'Loading',
      liveRegion: true,
      child: ExcludeSemantics(
        child: ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.all(SrSpace.gutter(context)),
          itemCount: widget.count,
          itemBuilder: (context, i) => FadeTransition(
            opacity: Tween<double>(begin: 0.55, end: 1).animate(_c),
            child: const _SkeletonRow(),
          ),
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    const block = Color(0xFFE6EBF3);
    Widget bar(double? w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: block, borderRadius: BorderRadius.circular(6)),
        );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(SrRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: block, borderRadius: BorderRadius.circular(14))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [bar(160, 14), const SizedBox(height: 10), bar(null, 12), const SizedBox(height: 8), bar(90, 12)],
            ),
          ),
        ],
      ),
    );
  }
}
