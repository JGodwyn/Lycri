import 'dart:ui';
import 'package:flutter/material.dart';

/// Shows a dialog with the "Lycri" signature blur-fade transition.
///
/// This transition blurs the modal content as it enters (8.0 -> 0.0) 
/// and as it leaves (0.0 -> 8.0), while also scaling and fading.
Future<T?> showLycriDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color barrierColor = Colors.black54,
  bool barrierDismissible = true,
  String? barrierLabel,
  Duration transitionDuration = const Duration(milliseconds: 300),
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierColor: barrierColor,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel ?? 'Dismiss',
    transitionDuration: transitionDuration,
    pageBuilder: (context, animation, secondaryAnimation) {
      return builder(context);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              // Standard Lycri blur amount: 8.0 -> 0.0
              final blurAmount = (1.0 - animation.value) * 8.0;
              
              if (blurAmount <= 0.05) return child;

              return ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: blurAmount,
                  sigmaY: blurAmount,
                ),
                child: child,
              );
            },
          ),
        ),
      );
    },
  );
}
