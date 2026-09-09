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

  const StatusBadge({
    super.key,
    required this.text,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.fontSize = 12,
    this.padding,
  });

  factory StatusBadge.fromStatus(dynamic status) {
    final statusStr = status is Enum ? status.name : (status?.toString() ?? '');
    Color bg;
    Color fg;
    IconData ic;

    switch (statusStr.toLowerCase()) {
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

    return StatusBadge(
      text: status,
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
          color: effectiveTextColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: effectiveTextColor),
            const SizedBox(width: 4),
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
