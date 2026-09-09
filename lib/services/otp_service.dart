 import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

enum OtpStatus {
  success,
  invalid,
  expired,
  error,
}

class OtpVerificationResult {
  final OtpStatus status;
  final String message;

  const OtpVerificationResult({required this.status, required this.message});

  bool get isSuccess => status == OtpStatus.success;
}

class _LocalOtpEntry {
  final String otp;
  final DateTime expiresAt;
  bool isUsed;

  _LocalOtpEntry({
    required this.otp,
    required this.expiresAt,
    this.isUsed = false,
  });
}

class OtpService {
  static final OtpService instance = OtpService._();
  OtpService._();

  SupabaseClient? get _supabase {
    try {
      return SupabaseConfig.client;
    } catch (_) {
      return null;
    }
  }

  // In-memory fallback store: ensures OTP flow works even if offline
  final Map<String, _LocalOtpEntry> _localOtpCache = {};

  /// Sends a Password Reset request through Supabase Auth (which delivers the
  /// 6-digit OTP code to the user's Gmail inbox) and creates a backup local OTP.
  Future<String> requestPasswordReset(String email) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. Generate a 6-digit backup OTP (100000 to 999999)
    final random = Random.secure();
    final localOtp = (100000 + random.nextInt(900000)).toString();
    final expiresAt = DateTime.now().toUtc().add(const Duration(minutes: 10));

    _localOtpCache[cleanEmail] = _LocalOtpEntry(
      otp: localOtp,
      expiresAt: expiresAt,
      isUsed: false,
    );

    // 2. Trigger Supabase Auth Password Reset / OTP Email directly
    final client = _supabase;
    if (client != null) {
      try {
        await client.auth.resetPasswordForEmail(cleanEmail);
        debugPrint('Supabase resetPasswordForEmail sent successfully');
      } catch (e) {
        debugPrint('Supabase resetPasswordForEmail: $e');
        try {
          // If user not in auth.users, try signInWithOtp to trigger Supabase OTP email
          await client.auth.signInWithOtp(
            email: cleanEmail,
            shouldCreateUser: true,
          );
          debugPrint('Supabase signInWithOtp sent successfully');
        } catch (e2) {
          debugPrint('Supabase signInWithOtp: $e2');
        }
      }

      // Also attempt to store in password_resets table if exists
      try {
        await client
            .from('password_resets')
            .update({'is_used': true})
            .eq('email', cleanEmail)
            .eq('is_used', false);

        await client.from('password_resets').insert({
          'email': cleanEmail,
          'otp': localOtp,
          'expires_at': expiresAt.toIso8601String(),
          'is_used': false,
        });
      } catch (_) {}
    }

    return localOtp;
  }

  /// Verifies the 6-digit OTP using Supabase Auth (recovery token) first,
  /// with local cache fallback.
  Future<OtpVerificationResult> verifyOtp(String email, String enteredOtp) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanOtp = enteredOtp.trim();

    // 1. First attempt verification with Supabase Auth (recovery or email token)
    final client = _supabase;
    if (client != null) {
      try {
        final authResponse = await client.auth.verifyOTP(
          email: cleanEmail,
          token: cleanOtp,
          type: OtpType.recovery,
        );

        if (authResponse.session != null || authResponse.user != null) {
          return const OtpVerificationResult(
            status: OtpStatus.success,
            message: 'OTP verified successfully via Supabase Auth!',
          );
        }
      } catch (e) {
        debugPrint('Supabase Auth verifyOTP (recovery): $e');
      }

      try {
        final authResponse = await client.auth.verifyOTP(
          email: cleanEmail,
          token: cleanOtp,
          type: OtpType.email,
        );

        if (authResponse.session != null || authResponse.user != null) {
          return const OtpVerificationResult(
            status: OtpStatus.success,
            message: 'OTP verified successfully via Supabase Auth!',
          );
        }
      } catch (e) {
        debugPrint('Supabase Auth verifyOTP (email): $e');
      }
    }

    // 2. Check the local resilient cache
    final localEntry = _localOtpCache[cleanEmail];
    if (localEntry != null && localEntry.otp == cleanOtp) {
      if (localEntry.isUsed) {
        return const OtpVerificationResult(
          status: OtpStatus.invalid,
          message: 'This OTP code has already been used. Please request a new one.',
        );
      }

      if (DateTime.now().toUtc().isAfter(localEntry.expiresAt)) {
        return const OtpVerificationResult(
          status: OtpStatus.expired,
          message: 'OTP has expired. Please request a new code.',
        );
      }

      localEntry.isUsed = true;
      return const OtpVerificationResult(
        status: OtpStatus.success,
        message: 'OTP verified successfully!',
      );
    }

    // 3. Check Supabase password_resets table if available
    if (client != null) {
      try {
        final response = await client
            .from('password_resets')
            .select()
            .eq('email', cleanEmail)
            .eq('otp', cleanOtp)
            .eq('is_used', false)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (response != null) {
          final expiresAtStr = response['expires_at'] as String?;
          if (expiresAtStr != null) {
            final exp = DateTime.tryParse(expiresAtStr)?.toUtc();
            if (exp != null && DateTime.now().toUtc().isAfter(exp)) {
              return const OtpVerificationResult(
                status: OtpStatus.expired,
                message: 'OTP has expired. Please request a new code.',
              );
            }
          }

          final id = response['id'];
          if (id != null) {
            await client
                .from('password_resets')
                .update({'is_used': true})
                .eq('id', id);
          }

          return const OtpVerificationResult(
            status: OtpStatus.success,
            message: 'OTP verified successfully!',
          );
        }
      } catch (_) {}
    }

    return const OtpVerificationResult(
      status: OtpStatus.invalid,
      message: 'Incorrect OTP code. Please check your Gmail (including Spam folder) and try again.',
    );
  }
}
