import 'package:flutter/material.dart';

/// Ethiyo brand assets. Register them in pubspec.yaml:
///
///   flutter:
///     assets:
///       - assets/images/
class EthiyoAssets {
  EthiyoAssets._();
  static const logo = 'assets/images/ethiyo_logo.png';
  static const hero = 'assets/images/ethiyo_hero.jpg';
}

/// The scenic hero illustration (bus, school, road). Falls back to a brand
/// gradient if the asset is missing so a pubspec slip never crashes a screen.
class EthiyoHeroImage extends StatelessWidget {
  const EthiyoHeroImage({super.key, this.alignment = Alignment.center, this.cacheWidth = 1000});
  final Alignment alignment;

  /// Decode width in pixels; keeps memory low on budget phones.
  final int cacheWidth;

  @override
  Widget build(BuildContext context) => Image.asset(
        EthiyoAssets.hero,
        fit: BoxFit.cover,
        alignment: alignment,
        cacheWidth: cacheWidth,
        excludeFromSemantics: true,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1585E8), Color(0xFF0B2A5B)],
            ),
          ),
        ),
      );
}

/// The Ethiyo wordmark + emblem on a transparent background.
class EthiyoLogo extends StatelessWidget {
  const EthiyoLogo({super.key, this.width = 180});
  final double width;

  @override
  Widget build(BuildContext context) => Image.asset(
        EthiyoAssets.logo,
        width: width,
        fit: BoxFit.contain,
        cacheWidth: (width * 3).round(),
        semanticLabel: 'Ethiyo',
        errorBuilder: (context, error, stackTrace) => Text(
          'Ethiyo',
          style: TextStyle(fontSize: width / 5, fontWeight: FontWeight.w900, color: const Color(0xFF0B2A5B)),
        ),
      );
}

/// Logo on a soft white card, so it stays legible over the photographic hero.
class EthiyoLogoCard extends StatelessWidget {
  const EthiyoLogoCard({super.key, this.width = 168});
  final double width;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [BoxShadow(color: const Color(0xFF0B2A5B).withValues(alpha: 0.22), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: EthiyoLogo(width: width),
      );
}
