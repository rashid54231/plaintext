import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../config/supabase_config.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_textfield.dart';
import '../../../services/database_service.dart';
import '../../../services/otp_service.dart';
import 'widgets/animated_auth_background.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Step tracker: 0 = Email, 1 = 6-Digit OTP, 2 = New Password
  int _currentStep = 0;

  // Form Keys & Controllers
  final _emailFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // 6 Digit OTP controllers & focus nodes (Supabase standard)
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _userEmail;

  // Resend countdown timer
  Timer? _resendTimer;
  int _resendCountdown = 60;
  bool _canResend = false;

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _otpFocusNodes) {
      f.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendCountdown = 60;
      _canResend = false;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown > 1) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
        setState(() => _canResend = true);
      }
    });
  }

  String get _enteredOtp =>
      _otpControllers.map((c) => c.text.trim()).join();

  void _clearOtpFields() {
    for (var c in _otpControllers) {
      c.clear();
    }
    if (_otpFocusNodes.isNotEmpty) {
      _otpFocusNodes[0].requestFocus();
    }
  }

  void _showOtpSentBanner() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'OTP Sent to your Email!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    'Please check your Email Inbox & Spam folder for the 6-digit code.',
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4F46E5),
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ============================================
  // STEP 1: SEND 6-DIGIT OTP VIA SUPABASE
  // ============================================
  Future<void> _handleSendOtp() async {
    if (!_emailFormKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    setState(() => _isLoading = true);

    try {
      final db = DatabaseService.instance;
      final user = await db.getUserByEmail(email);

      if (user == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No account found with this email in the database.'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        return;
      }

      // Trigger Supabase Auth Password Reset Email
      await OtpService.instance.requestPasswordReset(email);

      if (mounted) {
        setState(() {
          _userEmail = email;
          _currentStep = 1;
          _isLoading = false;
        });
        _clearOtpFields();
        _startResendTimer();
        _showOtpSentBanner();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // ============================================
  // RESEND OTP
  // ============================================
  Future<void> _handleResendOtp() async {
    if (!_canResend || _userEmail == null) return;

    setState(() => _isLoading = true);
    try {
      await OtpService.instance.requestPasswordReset(_userEmail!);
      if (mounted) {
        setState(() => _isLoading = false);
        _clearOtpFields();
        _startResendTimer();
        _showOtpSentBanner();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resend code: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // ============================================
  // STEP 2: VERIFY 6-DIGIT OTP
  // ============================================
  Future<void> _handleVerifyOtp() async {
    final entered = _enteredOtp;
    if (entered.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter all 6 digits of the OTP code.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result =
          await OtpService.instance.verifyOtp(_userEmail!, entered);

      if (mounted) {
        setState(() => _isLoading = false);
        if (result.isSuccess) {
          setState(() {
            _currentStep = 2;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('OTP Verified! Please set your new password.'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification error: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // ============================================
  // STEP 3: SET NEW PASSWORD
  // ============================================
  Future<void> _handleResetPassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final newPassword = _newPasswordController.text;
      final db = DatabaseService.instance;

      // 1. Update password in public.users table
      await db.updateUserPassword(_userEmail!, newPassword);

      // 2. Also update in Supabase Auth if session active
      try {
        await SupabaseConfig.client.auth.updateUser(
          UserAttributes(password: newPassword),
        );
        await SupabaseConfig.client.auth.signOut();
      } catch (_) {}

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Password updated successfully! Please login.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update password: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // ============================================
  // PASTE CLIPBOARD HANDLER FOR 6 DIGITS
  // ============================================
  Future<void> _handleClipboardPaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    final digitsOnly = text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.length >= 6) {
      for (int i = 0; i < 6; i++) {
        _otpControllers[i].text = digitsOnly[i];
      }
      _otpFocusNodes[5].unfocus();
      setState(() {});
      _handleVerifyOtp();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              digitsOnly.isEmpty
                  ? 'Clipboard does not contain any digits.'
                  : 'Clipboard code has only ${digitsOnly.length} digits (needs 6).',
            ),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Reset Password',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: AnimatedAuthBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHeaderIcon(),
                  const SizedBox(height: 20),
                  _buildTitleAndSubtitle(),
                  const SizedBox(height: 24),
                  _buildStepIndicators(),
                  const SizedBox(height: 24),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withOpacity(0.35)
                              : Colors.white.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.15)
                                : Colors.white.withOpacity(0.8),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                              blurRadius: 40,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.05, 0),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: _buildCurrentStepContent(isDark),
                        ),
                      ),
                    ),
                  ).animate().fade(duration: 700.ms).slideY(begin: 0.1, curve: Curves.easeOutQuad),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIcon() {
    IconData icon;
    if (_currentStep == 0) {
      icon = Icons.email_outlined;
    } else if (_currentStep == 1) {
      icon = Icons.mark_email_read_outlined;
    } else {
      icon = Icons.lock_reset_rounded;
    }

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
          )
        ],
      ),
      child: Icon(
        icon,
        size: 42,
        color: Colors.white,
      ),
    ).animate().fade(duration: 500.ms).scale(begin: const Offset(0.8, 0.8));
  }

  Widget _buildTitleAndSubtitle() {
    String title;
    String subtitle;

    if (_currentStep == 0) {
      title = 'Find Your Account';
      subtitle = 'Enter your email to receive an OTP code from Supabase';
    } else if (_currentStep == 1) {
      title = 'Enter 6-Digit OTP';
      subtitle = 'We sent a verification code to ${_userEmail ?? 'your Gmail'}';
    } else {
      title = 'Create New Password';
      subtitle = 'Choose a strong password with at least 6 characters';
    }

    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Color(0xFFE2E8F0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(bounds),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: Colors.white.withOpacity(0.85),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStepIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepPill(0, 'Email'),
        _buildStepDivider(0),
        _buildStepPill(1, '6-Digit OTP'),
        _buildStepDivider(1),
        _buildStepPill(2, 'Password'),
      ],
    );
  }

  Widget _buildStepPill(int step, String label) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.white
            : isCompleted
                ? AppColors.success.withOpacity(0.8)
                : Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCompleted)
            const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          else
            Text(
              '${step + 1}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isActive ? AppColors.primary : Colors.white,
              ),
            ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive ? AppColors.primary : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDivider(int step) {
    final isCompleted = _currentStep > step;
    return Container(
      width: 16,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: isCompleted ? AppColors.success : Colors.white.withOpacity(0.3),
    );
  }

  Widget _buildCurrentStepContent(bool isDark) {
    if (_currentStep == 0) {
      return _buildEmailStep();
    } else if (_currentStep == 1) {
      return _buildOtpStep(isDark);
    } else {
      return _buildPasswordStep();
    }
  }

  Widget _buildEmailStep() {
    return Form(
      key: _emailFormKey,
      child: Column(
        key: const ValueKey('step_email'),
        children: [
          CustomTextField(
            controller: _emailController,
            label: 'Email Address',
            hint: 'hello@example.com',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email is required';
              }
              if (!value.contains('@') || !value.contains('.')) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 28),
          CustomButton(
            text: 'Send OTP via Supabase',
            isLoading: _isLoading,
            onPressed: _handleSendOtp,
            icon: Icons.send_rounded,
            height: 54,
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep(bool isDark) {
    return Column(
      key: const ValueKey('step_otp'),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                _userEmail ?? '',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: AppColors.primary,
              tooltip: 'Change Email',
              onPressed: () {
                setState(() => _currentStep = 0);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 6-Digit Input Boxes (3 + 3 Group) with responsive FittedBox
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: List.generate(3, (index) => _buildDigitBox(index, isDark)),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 12,
                height: 3,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white38 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: List.generate(3, (index) => _buildDigitBox(index + 3, isDark)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        TextButton.icon(
          onPressed: _handleClipboardPaste,
          icon: const Icon(Icons.content_paste_rounded, size: 16),
          label: const Text('Paste Code from Clipboard', style: TextStyle(fontSize: 13)),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            visualDensity: VisualDensity.compact,
          ),
        ),

        const SizedBox(height: 20),

        CustomButton(
          text: 'Verify Code',
          isLoading: _isLoading,
          onPressed: _handleVerifyOtp,
          icon: Icons.check_circle_outline_rounded,
          height: 54,
        ),

        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timer_outlined, size: 16, color: isDark ? Colors.white60 : Colors.black54),
            const SizedBox(width: 6),
            if (!_canResend)
              Text(
                'Resend code in 00:${_resendCountdown.toString().padLeft(2, '0')}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              )
            else
              TextButton(
                onPressed: _isLoading ? null : _handleResendOtp,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Resend OTP Code',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDigitBox(int index, bool isDark) {
    return Container(
      width: 44,
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              _otpControllers[index].text.isEmpty &&
              index > 0) {
            _otpFocusNodes[index - 1].requestFocus();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextFormField(
          controller: _otpControllers[index],
          focusNode: _otpFocusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.zero,
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.04),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.white24 : Colors.black12,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 2,
              ),
            ),
          ),
          onChanged: (value) {
            final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
            // When user pastes all 6 digits into any box
            if (digits.length >= 6) {
              for (int i = 0; i < 6; i++) {
                _otpControllers[i].text = digits[i];
              }
              _otpFocusNodes[5].unfocus();
              _handleVerifyOtp();
              return;
            }

            if (digits.isNotEmpty) {
              final lastChar = digits[digits.length - 1];
              _otpControllers[index].value = TextEditingValue(
                text: lastChar,
                selection: const TextSelection.collapsed(offset: 1),
              );
              if (index < 5) {
                _otpFocusNodes[index + 1].requestFocus();
              } else {
                _otpFocusNodes[index].unfocus();
                if (_enteredOtp.length == 6) {
                  _handleVerifyOtp();
                }
              }
            } else if (digits.isEmpty && index > 0) {
              _otpFocusNodes[index - 1].requestFocus();
            }
          },
        ),
      ),
    );
  }

  Widget _buildPasswordStep() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        key: const ValueKey('step_password'),
        children: [
          CustomTextField(
            controller: _newPasswordController,
            label: 'New Password',
            hint: 'Enter new password',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: AppColors.textHint,
                size: 22,
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password is required';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _confirmPasswordController,
            label: 'Confirm Password',
            hint: 'Re-enter new password',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscureConfirmPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: AppColors.textHint,
                size: 22,
              ),
              onPressed: () {
                setState(() =>
                    _obscureConfirmPassword = !_obscureConfirmPassword);
              },
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm password';
              }
              if (value != _newPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 28),
          CustomButton(
            text: 'Update Password',
            isLoading: _isLoading,
            onPressed: _handleResetPassword,
            icon: Icons.check_circle_rounded,
            height: 54,
          ),
        ],
      ),
    );
  }
}
