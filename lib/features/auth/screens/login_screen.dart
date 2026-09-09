import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/user_provider.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_textfield.dart';
import '../../dashboard/screens/manager_dashboard.dart';
import '../../dashboard/screens/student_dashboard.dart';
import 'widgets/animated_auth_background.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final userProvider = context.read<UserProvider>();
    final success = await userProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      final user = userProvider.currentUser;
      Widget destination;
      if (user!.isManager) {
        destination = const ManagerDashboard();
      } else {
        destination = const StudentDashboard();
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => destination),
      );
    } else if (mounted && userProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userProvider.error!),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: AnimatedAuthBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildHeader(isDark).animate().fade(duration: 600.ms).slideY(begin: 0.2, curve: Curves.easeOutQuad),
              const SizedBox(height: 40),
              _buildLoginCard(isDark).animate().fade(duration: 800.ms, delay: 200.ms).slideY(begin: 0.1, curve: Curves.easeOutQuad),
              const SizedBox(height: 32),
              _buildSignUpLink().animate().fade(duration: 800.ms, delay: 400.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.task_alt_rounded,
            size: 44,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Color(0xFFE2E8F0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(bounds),
          child: Text(
            'TaskFlow',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Sign in to organize your tasks',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            color: Colors.white.withValues(alpha: 0.85),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.9),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Login',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
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
                    if (!value.contains('@')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                CustomTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: '••••••••',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
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
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Forgot Password?',
                      style: GoogleFonts.plusJakartaSans(
                        color: isDark ? AppColors.primaryLight : AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                CustomButton(
                  text: 'Sign In',
                  isLoading: _isLoading,
                  onPressed: _handleLogin,
                  icon: Icons.login_rounded,
                  height: 54,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SignupScreen()),
            );
          },
          child: Text(
            'Sign Up',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}