import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isOutlined;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double? height;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> with SingleTickerProviderStateMixin {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails details) {
    if (!widget.isLoading) setState(() => _scale = 0.95);
  }

  void _onTapUp(TapUpDetails details) {
    if (!widget.isLoading) setState(() => _scale = 1.0);
  }

  void _onTapCancel() {
    if (!widget.isLoading) setState(() => _scale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.isOutlined) {
      return GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          child: SizedBox(
            width: widget.width ?? double.infinity,
            height: widget.height ?? 54,
            child: OutlinedButton(
              onPressed: widget.isLoading ? null : widget.onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: widget.textColor ?? AppColors.primary,
                side: BorderSide(
                  color: widget.backgroundColor ?? AppColors.primary,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: widget.isLoading
                  ? SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: widget.textColor ?? AppColors.primary,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, size: 22),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          widget.text,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        child: Container(
          width: widget.width ?? double.infinity,
          height: widget.height ?? 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: widget.backgroundColor == null ? AppColors.primaryGradient : null,
            color: widget.backgroundColor,
            boxShadow: [
              BoxShadow(
                color: (widget.backgroundColor ?? AppColors.primary).withOpacity(isDark ? 0.2 : 0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: widget.isLoading ? null : widget.onPressed,
              splashColor: Colors.white.withOpacity(0.2),
              highlightColor: Colors.transparent,
              child: Center(
                child: widget.isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, size: 22, color: widget.textColor ?? Colors.white),
                            const SizedBox(width: 10),
                          ],
                          Text(
                            widget.text,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: widget.textColor ?? Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
