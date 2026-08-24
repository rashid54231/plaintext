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
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF070B14), Color(0xFF131034)], // Darker rich colors
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF9333EA)], // Rich indigo to purple
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
      ),
      child: Stack(
        children: [
          // Animated Orb 1
          Positioned(
            top: size.height * -0.1,
            left: size.width * -0.2,
            child: Container(
              width: size.width * 0.8,
              height: size.width * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isDark ? AppColors.secondary : Colors.white).withOpacity(0.2),
              ),
            ).animate(
              onPlay: (controller) => controller.repeat(reverse: true),
            ).scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1.2, 1.2),
              duration: 8.seconds,
              curve: Curves.easeInOutSine,
            ).move(
              duration: 12.seconds,
              begin: const Offset(-20, -20),
              end: const Offset(20, 20),
              curve: Curves.easeInOutSine,
            ),
          ),
          
          // Animated Orb 2
          Positioned(
            bottom: size.height * -0.1,
            right: size.width * -0.3,
            child: Container(
              width: size.width * 0.9,
              height: size.width * 0.9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isDark ? AppColors.primary : Colors.white).withOpacity(0.25),
              ),
            ).animate(
              onPlay: (controller) => controller.repeat(reverse: true),
            ).scale(
              begin: const Offset(1.2, 1.2),
              end: const Offset(0.8, 0.8),
              duration: 10.seconds,
              curve: Curves.easeInOutSine,
            ).move(
              duration: 15.seconds,
              begin: const Offset(30, 30),
              end: const Offset(-30, -30),
              curve: Curves.easeInOutSine,
            ),
          ),

          // Blur layer over the orbs to create a soft glowing ambient effect
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: const SizedBox(),
            ),
          ),

          // Noise texture (Optional, but adds a very premium feel)
          Positioned.fill(
            child: Opacity(
              opacity: 0.03,
              child: Image.network(
                'https://www.transparenttextures.com/patterns/stardust.png',
                repeat: ImageRepeat.repeat,
              ),
            ),
          ),

          // Main Content Layer
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
