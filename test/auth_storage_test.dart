import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plaintext/models/user.dart';
import 'package:plaintext/services/auth_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthStorageService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('should save and retrieve user session correctly', () async {
      final authStorage = AuthStorageService.instance;

      final testUser = User(
        id: 'test-user-uuid-123',
        name: 'Rashid Khan',
        email: 'rashid@example.com',
        password: 'password123',
        role: Role.manager,
        phone: '+919876543210',
      );

      // Initially no session
      final initialSession = await authStorage.getSession();
      expect(initialSession, isNull);
      expect(await authStorage.hasSession(), isFalse);

      // Save session
      await authStorage.saveSession(testUser);

      // Verify session exists
      expect(await authStorage.hasSession(), isTrue);
      final retrievedUser = await authStorage.getSession();
      expect(retrievedUser, isNotNull);
      expect(retrievedUser!.id, equals('test-user-uuid-123'));
      expect(retrievedUser.name, equals('Rashid Khan'));
      expect(retrievedUser.email, equals('rashid@example.com'));
      expect(retrievedUser.isManager, isTrue);

      // Clear session
      await authStorage.clearSession();
      expect(await authStorage.hasSession(), isFalse);
      expect(await authStorage.getSession(), isNull);
    });
  });
}
