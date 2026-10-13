import 'package:flutter/material.dart';

Route<T> srFadeRoute<T>(Widget page) => PageRouteBuilder<T>(
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: const Cubic(0.22, 1, 0.36, 1),
          reverseCurve: Curves.easeInCubic,
        );
        final fade = CurvedAnimation(
          parent: animation,
          curve: const Interval(0, 0.8, curve: Curves.easeOut),
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
              child: child,
            ),
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 360),
      reverseTransitionDuration: const Duration(milliseconds: 240),
    );
