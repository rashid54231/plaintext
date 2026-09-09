import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';

class AnimatedAuthBackground extends StatelessWidget {
  final Widget child;
  const AnimatedAuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: isDark ? const Color(0xFF070B14) : const Color(0xFF0F172A),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. High-tech 3D TaskFlow productivity background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/auth_bg.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // 2. Translucent gradient scrim to ensure high readability for login inputs
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    (isDark ? const Color(0xFF060913) : const Color(0xFF1E1B4B)).withValues(alpha: 0.72),
                    (isDark ? const Color(0xFF0A0F1E) : const Color(0xFF0F172A)).withValues(alpha: 0.88),
                  ],
                ),
              ),
            ),
          ),

          // 3. Subtle animated ambient glowing orbs for depth
          Positioned(
            top: size.height * 0.05,
            right: -size.width * 0.2,
            child: Container(
              width: size.width * 0.7,
              height: size.width * 0.7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withValues(alpha: 0.25),
              ),
            ).animate(
              onPlay: (controller) => controller.repeat(reverse: true),
            ).scale(
              begin: const Offset(0.9, 0.9),
              end: const Offset(1.2, 1.2),
              duration: 8.seconds,
              curve: Curves.easeInOutSine,
            ),
          ),

          Positioned(
            bottom: size.height * 0.1,
            left: -size.width * 0.25,
            child: Container(
              width: size.width * 0.75,
              height: size.width * 0.75,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ).animate(
              onPlay: (controller) => controller.repeat(reverse: true),
            ).scale(
              begin: const Offset(1.1, 1.1),
              end: const Offset(0.85, 0.85),
              duration: 9.seconds,
              curve: Curves.easeInOutSine,
            ),
          ),

          // 4. Subtle ambient blur over orbs to blend with holographic lights
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: const SizedBox(),
            ),
          ),

          // 5. Main Content Layer
          SafeArea(
            child: Center(
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

