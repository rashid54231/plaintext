import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String text;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final double fontSize;
  final EdgeInsetsGeometry? padding;
  final bool showDot;

  const StatusBadge({
    super.key,
    required this.text,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.fontSize = 11,
    this.padding,
    this.showDot = true,
  });

  factory StatusBadge.fromStatus(dynamic status) {
    final rawStr = status is Enum ? status.name : (status?.toString() ?? '');
    Color bg;
    Color fg;
    IconData ic;

    switch (rawStr.toLowerCase()) {
      case 'completed':
        bg = AppColors.success;
        fg = AppColors.success;
        ic = Icons.check_circle_rounded;
        break;
      case 'pending':
        bg = AppColors.warning;
        fg = AppColors.warning;
        ic = Icons.hourglass_bottom_rounded;
        break;
      case 'overdue':
        bg = AppColors.error;
        fg = AppColors.error;
        ic = Icons.warning_rounded;
        break;
      case 'high':
        bg = AppColors.highPriority;
        fg = AppColors.highPriority;
        ic = Icons.flag_rounded;
        break;
      case 'medium':
        bg = AppColors.mediumPriority;
        fg = AppColors.mediumPriority;
        ic = Icons.flag_outlined;
        break;
      case 'low':
        bg = AppColors.lowPriority;
        fg = AppColors.lowPriority;
        ic = Icons.outlined_flag_rounded;
        break;
      default:
        bg = AppColors.primary;
        fg = AppColors.primary;
        ic = Icons.label_outline_rounded;
    }

    final formattedText = rawStr.isNotEmpty 
        ? '${rawStr[0].toUpperCase()}${rawStr.substring(1)}'
        : 'Status';

    return StatusBadge(
      text: formattedText,
      backgroundColor: bg.withValues(alpha: 0.12),
      textColor: fg,
      icon: ic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTextColor = textColor ?? AppColors.primary;
    final effectiveBg = backgroundColor ?? effectiveTextColor.withValues(alpha: 0.12);

    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: effectiveTextColor.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 3, color: effectiveTextColor),
            const SizedBox(width: 4),
          ] else if (showDot) ...[
            Container(
              width: 5.5,
              height: 5.5,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: effectiveTextColor,
                boxShadow: [
                  BoxShadow(
                    color: effectiveTextColor.withValues(alpha: 0.5),
                    blurRadius: 4,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
            ),
          ],
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: effectiveTextColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
