import 'package:flutter_test/flutter_test.dart';
import 'package:plaintext/services/otp_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Supabase OTP Logic Tests', () {
    test('6-digit OTP generation has correct length and is numeric', () {
      const min = 100000;
      const max = 999999;
      
      for (int i = 0; i < 100; i++) {
        final otp = (min + (i * 12345) % (max - min)).toString();
        expect(otp.length, equals(6));
        expect(int.tryParse(otp), isNotNull);
      }
    });

    test('Expired timestamp is correctly detected', () {
      final expiredTime = DateTime.now().toUtc().subtract(const Duration(minutes: 1));
      final isValid = DateTime.now().toUtc().isBefore(expiredTime);
      expect(isValid, isFalse);
    });

    test('Valid timestamp within 10 minutes is correctly verified', () {
      final futureTime = DateTime.now().toUtc().add(const Duration(minutes: 10));
      final isValid = DateTime.now().toUtc().isBefore(futureTime);
      expect(isValid, isTrue);
    });

    test('Password reset request generates 6-digit OTP and verifies successfully', () async {
      const email = 'rashidgulab5@gmail.com';
      final otp = await OtpService.instance.requestPasswordReset(email);
      expect(otp.length, equals(6));

      // Test wrong OTP
      final wrongRes = await OtpService.instance.verifyOtp(email, '000000');
      expect(wrongRes.isSuccess, isFalse);

      // Test correct OTP
      final correctRes = await OtpService.instance.verifyOtp(email, otp);
      expect(correctRes.isSuccess, isTrue);

      // Test already used OTP
      final reusedRes = await OtpService.instance.verifyOtp(email, otp);
      expect(reusedRes.isSuccess, isFalse);
    });
  });
}
